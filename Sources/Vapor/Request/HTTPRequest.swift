import NIO
import HTTP
import Routing

extension HTTPRequest {
    internal var _parameters: Parameters {
        get { return self.userInfo["parameters"] as? Parameters ?? .init() }
        set { self.userInfo["parameters"] = newValue }
    }
    
    public var parameters: ParametersContainer {
        return .init(self)
    }
}
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
//public final class HTTPRequest: HTTPMessageContainer, HTTPRequestEncodable, CustomStringConvertible, CustomDebugStringConvertible {
//    // MARK: HTTP
//
//    /// The wrapped `HTTPRequest`.
//    ///
//    ///     print(req.http.url.path) // "/hello"
//    ///
//    public var http: HTTPRequest
//    
//    public var channel: Channel
//    
//    public var eventLoop: EventLoop {
//        return self.channel.eventLoop
//    }
//    
//    public var userInfo: [AnyHashable: Any]
//
//    /// `true` if this request has active connections. This is used to avoid unnecessarily
//    /// invoking cached connections release.
//    internal var hasActiveConnections: Bool
//
//    // MARK: Descriptions
//
//    /// See `CustomStringConvertible`.
//    public var description: String {
//        return http.description
//    }
//
//    /// See `CustomDebugStringConvertible`.
//    public var debugDescription: String {
//        return http.debugDescription
//    }
//
//    // MARK: Content
//
//    /// Helper for encoding and decoding data from an HTTP request query string.
//    ///
//    ///     let flags = try req.query.decode(Flags.self)
//    ///     print(flags) // Flags
//    ///
//    /// This helper can also decode single values from specific key paths.
//    ///
//    ///     let name = try req.query.get(String.self, at: "user", "name")
//    ///     print(name) // String
//    ///
//    /// See `QueryContainer` methods for more information.
//    public var query: Any {
//        #warning("TODO: update QueryContainer")
//        fatalError()
//    }
//
//    /// Helper for encoding and decoding `Content` from an HTTP message.
//    ///
//    /// This helper can _encode_ data to the HTTP message. Uses the Content's default media type if none is supplied.
//    ///
//    ///     try req.content.encode(user)
//    ///
//    /// This helper can also _decode_ data from the HTTP message.
//    ///
//    ///     let user = try req.content.decode(User.self)
//    ///     print(user) /// Future<User>
//    ///
//    /// See `ContentContainer` methods for more information.
//    public var content: HTTPContentContainer<HTTPRequest> {
//        get { return .init(self.http) }
//        set { self.http = newValue.message }
//    }
//
//    // MARK: Routing
//
//    /// Helper for accessing route parameters from this HTTP request.
//    ///
//    ///     let id = try req.parameters.next(Int.self)
//    ///
//    public var parameters: ParametersContainer {
//        return .init(self)
//    }
//
//    /// Internal storage for routing parameters.
//    internal var _parameters: Parameters
//
//    // MARK: Init
//
//    /// Create a new `Request`.
//    public init(http: HTTPRequest = .init(), on channel: Channel) {
//        self.http = http
//        self.channel = channel
//        self.userInfo = [:]
//        self._parameters = .init()
//        hasActiveConnections = false
//    }
//
//    /// See `HTTPRequestEncodable`.
//    public func encode(on eventLoop: EventLoop) -> EventLoopFuture<HTTPRequest> {
//        return eventLoop.makeSucceededFuture(result: self.http)
//    }
//}
