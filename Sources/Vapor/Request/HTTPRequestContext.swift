import NIO
import HTTP
import Routing

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
public final class HTTPRequestContext: HTTPMessageContainer, HTTPRequestCodable, CustomStringConvertible, CustomDebugStringConvertible {
    // MARK: HTTP

    /// The wrapped `HTTPRequest`.
    ///
    ///     print(req.http.url.path) // "/hello"
    ///
    public var http: HTTPRequest
    
    public var eventLoop: EventLoop
    
    public var userInfo: [AnyHashable: Any]

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
    public var query: Any {
        #warning("TODO: update QueryContainer")
        fatalError()
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
    public var content: ContentContainer<HTTPRequest> {
        get { return .init(message: self.http) }
        set { self.http = newValue.message }
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
    public init(http: HTTPRequest = .init(), on eventLoop: EventLoop) {
        self.http = http
        self.eventLoop = eventLoop
        self.userInfo = [:]
        self._parameters = .init()
        hasActiveConnections = false
    }

    // MARK: Response
    
    /// Creates a `HTTPResponse` on the same container as this `Request`.
    ///
    ///     router.get("greeting2") { req in
    ///         let res = req.response()
    ///         try res.content.encode("hello", as: .plaintext)
    ///         return res
    ///     }
    ///
    /// - returns: A new, empty 200 OK `Response` on the same container as the current `Request`.
    public func response() -> HTTPResponse {
        return .init()
    }

//    /// Generate a `Response` for a `HTTPBody` convertible object using the supplied `MediaType`.
//    ///
//    ///     router.get("html") { req in
//    ///         return req.response("<h1>Hello, world!</h1>", as: .html)
//    ///     }
//    ///
//    /// - parameters:
//    ///     - type: The type of data to return the container with.
//    public func response(_ body: LosslessHTTPBodyRepresentable, as contentType: HTTPMediaType = .plainText) -> Response {
//        let res = HTTPResponse(body: body)
//        res.contentType = contentType
//        return res
//    }

    // MARK: HTTP Request Codable

    /// See `HTTPRequestDecodable`.
    public static func decode(from request: HTTPRequest, on eventLoop: EventLoop) -> EventLoopFuture<HTTPRequestContext> {
        return eventLoop.makeSucceededFuture(result: .init(http: request, on: eventLoop))
    }

    /// See `HTTPRequestEncodable`.
    public func encode(on eventLoop: EventLoop) -> EventLoopFuture<HTTPRequest> {
        return eventLoop.makeSucceededFuture(result: self.http)
    }
}
