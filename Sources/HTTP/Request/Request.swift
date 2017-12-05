import Async
import Foundation

/// An HTTP request.
///
/// Used to request a response from an HTTP server.
///
///     POST /foo HTTP/1.1
///     Content-Length: 5
///
///     hello
///
/// The HTTP server will stream incoming requests from clients.
/// You must handle these requests and generate responses.
///
/// When you want to request data from another server, such as
/// calling another API from your application, you will create
/// a request and use the HTTP client to prompt a response
/// from the remote server.
///
///     let req = HTTPRequest(method: .post, body: "hello")
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/request/)
public struct HTTPRequest: HTTPMessage {
    /// HTTP requests have a method, like GET or POST
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/method/)
    public var method: HTTPMethod

    /// This is usually just a path like `/foo` but
    /// may be a full URI in the case of a proxy
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/uri/)
    public var uri: URI

    /// See `Message.version`
    public var version: HTTPVersion

    /// See `Message.headers`
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/headers/)
    public var headers: HTTPHeaders

    /// See `Message.body`
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
    public var body: HTTPBody

    /// See Message.onUpgrade
    public var onUpgrade: HTTPOnUpgrade?

    /// Create a new HTTP request.
    public init(
        method: HTTPMethod = .get,
        uri: URI = URI(),
        version: HTTPVersion = HTTPVersion(major: 1, minor: 1),
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBody = HTTPBody()
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
    }
}

// MARK: Convenience

extension HTTPRequest {
    /// Create a new HTTP request using something BodyRepresentable.
    public init(
        method: HTTPMethod = .get,
        uri: URI = URI(),
        version: HTTPVersion = HTTPVersion(major: 1, minor: 1),
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBodyRepresentable
    ) throws {
        try self.init(method: method, uri: uri, version: version, headers: headers, body: body.makeBody())
    }
}
