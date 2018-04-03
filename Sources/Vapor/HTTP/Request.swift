import Core
import HTTP
import Routing
import Service

/// `Request` is a service-container wrapper around an `HTTPRequest`.
///
/// Use this `Request` to access information about the `HTTPRequest` (`req.http`).
///
///     print(req.http.url.path) // "/hello"
///
/// You can also use `Request` to create services you may need while generating a response (`req.make(_:)`.
///
///     let client = try req.make(Client.self)
///     print(client) // Client
///     client.get("http://vapor.codes")
///
/// `Request` is also the `ParameterContainer` for routing. Use `.parameter(...)` to fetch parameterized values.
///
///     router.get("hello", String.parameter) { req in
///         let name = try req.parameter(String.self)
///         return "Hello, \(name)!"
///     }
///
/// `Request` is `DatabaseConnectable`, meaning you can use it in-place of an actual `DatabaseConnection`.
/// When used as a connection, the request will fetch a connection from the event loop's connection pool and
/// cache the connection for the lifetime of the request.
///
///     let users = User.query(on: req).all()
///
/// See `HTTPRequest`, `Container`, `ParameterContainer`, and `DatabaseConnectable` for more information.
public final class Request: ParameterContainer, ContainerAlias, DatabaseConnectable, CustomStringConvertible, CustomDebugStringConvertible {
    /// See `ContainerAlias`.
    public static let aliasedContainer: KeyPath<Request, Container> = \.sharedContainer

    // MARK: Stored

    /// The wrapped `HTTPRequest`.
    ///
    ///     print(req.http.url.path) // "/hello"
    ///
    public var http: HTTPRequest

    /// This `Request`'s parent container. This is normally the event loop. The `Request` will redirect
    /// all calls to create services to this container.
    public let sharedContainer: Container

    /// This request's private container. Use this container to create services that will be cached
    /// only for the lifetime of this request. For all other services, use the request directly.
    ///
    ///     let authCache = req.privateContainer.make(AuthCache.self)
    ///
    public let privateContainer: SubContainer

    /// Holds parameters for routing. See `ParameterContainer` for more information.
    public var parameters: Parameters
    
    /// `true` if this request has active connections. This is used to avoid unnecessarily
    /// invoking cached connections release.
    internal var hasActiveConnections: Bool

    // MARK: Computed

    /// See `CustomStringConvertible.description
    public var description: String {
        return http.description
    }

    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        return http.debugDescription
    }

    /// Helper for encoding and decoding data from an HTTP request query string.
    ///
    ///     let flags = try req.query.decode(Flags.self)
    ///     print(flags) /// Flags
    ///
    /// This helper can also decode single values from specific key paths.
    ///
    ///     let name = try req.query.get(String.self, at: "user", "name")
    ///     print(name) /// String
    ///
    /// See `QueryContainer` methods for more information.
    public var query: QueryContainer {
        return QueryContainer(container: self, query: http.url.query ?? "")
    }

    /// Helper for encoding and decoding `Content` from an HTTP message.
    ///
    /// This helpper can encode data to the HTTP message. Uses the Content's default media type if none is supplied.
    ///
    ///     try req.content.encode(user)
    ///
    /// This helper can also _decode_ data from the HTTP message.
    ///
    ///     let user = try req.content.decode(User.self)
    ///     print(user) /// Future<User>
    ///
    /// See `ContentContainer` methods for more information.
    public var content: ContentContainer {
        return ContentContainer(container: self, body: http.body, mediaType: http.mediaType) { body, mediaType in
            self.http.body = body
            self.http.mediaType = mediaType
        }
    }

    /// Create a new `Request`.
    public init(http: HTTPRequest = .init(), using container: Container) {
        self.http = http
        self.sharedContainer = container
        self.privateContainer = container.subContainer(on: container)
        self.parameters = []
        hasActiveConnections = false
    }

    // MARK: Methods

    /// Creates a `Response` on the same container as this `Request`.
    ///
    ///     router.get("greeting2") { req in
    ///         let res = req.makeResponse()
    ///         try res.content.encode("hello", as: .plaintext)
    ///         return res
    ///     }
    ///
    /// returns: A new, empty 200 OK `Response` on the same container as the current `Request`.
    public func makeResponse() -> Response {
        return Response(using: sharedContainer)
    }

    /// Creates a `DatabaseConnection` to the database specified by the supplied `DatabaseIdentifier`.
    ///
    /// This connection will be cached for the lifetime of this request.
    ///
    /// See `DatabaseConnectable.connect(to:)`
    public func connect<D>(to database: DatabaseIdentifier<D>?) -> Future<D.Connection> {
        guard let database = database else {
            let error = VaporError(
                identifier: "defaultDB",
                reason: "Model.defaultDatabase required to use request as worker.",
                suggestedFixes: [
                    "Ensure you are using the 'model' label when registering this model to your migration config (if it is a migration): migrations.add(model: ..., database: ...).",
                    "If the model you are using is not a migration, set the static defaultDatabase property manually in your app's configuration section.",
                    "Use req.withPooledConnection(to: ...) { ... } instead."
                ],
                source: .capture()
            )
            return Future.map(on: self) { throw error }
        }
        hasActiveConnections = true
        return requestCachedConnection(to: database)
    }

    /// Called when the `Request` deinitializes.
    deinit {
        if hasActiveConnections {
            try! releaseCachedConnections()
        }
    }
}
