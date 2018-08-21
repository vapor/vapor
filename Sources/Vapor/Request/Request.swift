/// `Request` is a service-container wrapper around an `HTTPRequest`.
///
/// Use `Request` to access information about the `HTTPRequest` (`req.http`).
///
///     print(req.http.url.path) // "/hello"
///
/// You can also use `Request` to create services you may need while generating a response (`req.make()`).
///
///     let client = try req.make(Client.self)
///     print(client) // Client
///     client.get("http://vapor.codes")
///
/// `Request` also carries a `ParametersContainer` for routing. Use `parameters` to fetch parameterized values.
///
///     router.get("hello", String.parameter) { req -> String in
///         let name = try req.parameters.next(String.self)
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
public final class Request: ContainerAlias, DatabaseConnectable, HTTPMessageContainer, RequestCodable, CustomStringConvertible, CustomDebugStringConvertible {
    /// See `ContainerAlias`.
    public static let aliasedContainer: KeyPath<Request, Container> = \.sharedContainer

    // MARK: HTTP

    /// The wrapped `HTTPRequest`.
    ///
    ///     print(req.http.url.path) // "/hello"
    ///
    public var http: HTTPRequest

    // MARK: Services

    /// This `Request`'s parent container. This is normally the event loop. The `Request` will redirect
    /// all calls to create services to this container.
    public let sharedContainer: Container

    /// This request's private container. Use this container to create services that will be cached
    /// only for the lifetime of this request. For all other services, use the request directly.
    ///
    ///     let authCache = try req.privateContainer.make(AuthCache.self)
    ///
    public let privateContainer: SubContainer

    /// `true` if this request has active connections. This is used to avoid unnecessarily
    /// invoking cached connections release.
    internal var hasActiveConnections: Bool

    // MARK: Descriptions

    /// See `CustomStringConvertible`.
    public var description: String {
        return http.description
    }

    /// See `CustomDebugStringConvertible`.
    public var debugDescription: String {
        return http.debugDescription
    }

    // MARK: Content

    /// Helper for encoding and decoding data from an HTTP request query string.
    ///
    ///     let flags = try req.query.decode(Flags.self)
    ///     print(flags) // Flags
    ///
    /// This helper can also decode single values from specific key paths.
    ///
    ///     let name = try req.query.get(String.self, at: "user", "name")
    ///     print(name) // String
    ///
    /// See `QueryContainer` methods for more information.
    public var query: QueryContainer {
        return .init(req: self)
    }

    /// Helper for encoding and decoding `Content` from an HTTP message.
    ///
    /// This helper can _encode_ data to the HTTP message. Uses the Content's default media type if none is supplied.
    ///
    ///     try req.content.encode(user)
    ///
    /// This helper can also _decode_ data from the HTTP message.
    ///
    ///     let user = try req.content.decode(User.self)
    ///     print(user) /// Future<User>
    ///
    /// See `ContentContainer` methods for more information.
    public var content: ContentContainer<Request> {
        return .init(self)
    }

    // MARK: Routing

    /// Helper for accessing route parameters from this HTTP request.
    ///
    ///     let id = try req.parameters.next(Int.self)
    ///
    public var parameters: ParametersContainer {
        return .init(self)
    }

    /// Internal storage for routing parameters.
    internal var _parameters: Parameters

    // MARK: Init

    /// Create a new `Request`.
    public init(http: HTTPRequest = .init(), using container: Container) {
        self.http = http
        self.sharedContainer = container
        self.privateContainer = container.subContainer(on: container)
        self._parameters = .init()
        hasActiveConnections = false
    }

    // MARK: Response
    
    /// Creates a `Response` on the same container as this `Request`.
    ///
    ///     router.get("greeting2") { req in
    ///         let res = req.response()
    ///         try res.content.encode("hello", as: .plaintext)
    ///         return res
    ///     }
    ///
    /// - parameters:
    ///     - http: Optional `HTTPResponse` to use.
    /// - returns: A new, empty 200 OK `Response` on the same container as the current `Request`.
    public func response(http: HTTPResponse = .init()) -> Response  {
        return Response(http: http, using: sharedContainer)
    }

    /// Generate a `Response` for a `HTTPBody` convertible object using the supplied `MediaType`.
    ///
    ///     router.get("html") { req in
    ///         return req.response("<h1>Hello, world!</h1>", as: .html)
    ///     }
    ///
    /// - parameters:
    ///     - type: The type of data to return the container with.
    public func response(_ body: LosslessHTTPBodyRepresentable, as contentType: MediaType = .plainText) -> Response {
        let res = response(http: .init(body: body))
        res.http.contentType = contentType
        return res
    }
    
    // MARK: Database

    /// See `DatabaseConnectable`.
    public func databaseConnection<D>(to database: DatabaseIdentifier<D>?) -> Future<D.Connection> {
        guard let database = database else {
            let error = VaporError(
                identifier: "defaultDB",
                reason: "`Model.defaultDatabase` is required to use request as `DatabaseConnectable`.",
                suggestedFixes: [
                    "Ensure you are using the 'model' label when registering this model to your migration config (if it is a migration): migrations.add(model: ..., database: ...).",
                    "If the model you are using is not a migration, set the static `defaultDatabase` property manually in your app's configuration section.",
                    "Use `req.withPooledConnection(to: ...) { ... }` instead."
                ]
            )
            return eventLoop.newFailedFuture(error: error)
        }
        hasActiveConnections = true
        return privateContainer.requestCachedConnection(to: database, poolContainer: self)
    }

    // MARK: Request Codable

    /// See `RequestDecodable`.
    public static func decode(from request: Request) throws -> Future<Request> {
        return Future.map(on: request) { request }
    }

    /// See `RequestEncodable`.
    public func encode(using container: Container) throws -> Future<Request> {
        return Future.map(on: container) { self }
    }

    /// Called when the `Request` deinitializes.
    deinit {
        if hasActiveConnections {
            try! privateContainer.releaseCachedConnections()
        }
    }
}
