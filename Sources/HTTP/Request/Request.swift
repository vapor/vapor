import Foundation
import Core

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
///     let req = Request(method: .post, body: "hello")
///
/// See Message
public final class Request: Message {
    /// HTTP requests have a method, like GET or POST
    public var method: Method

    /// This is usually just a path like `/foo` but
    /// may be a full URI in the case of a proxy
    public var uri: URI

    /// See Message.version
    public var version: Version

    /// See Message.headers
    public var headers: Headers

    /// See Message.body
    public var body: Body {
        didSet { updateContentLength() }
    }
    
    /// See Extendable.extend
    public var extend: Extend

    /// Create a new HTTP request.
    public init(
        method: Method = .get,
        uri: URI = URI(),
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: Body = Body()
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
        self.extend = Extend()
        updateContentLength()
    }
}

// MARK: Convenience

extension Request {
    /// Create a new HTTP request using something BodyRepresentable.
    public convenience init(
        method: Method = .get,
        uri: URI = URI(),
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: BodyRepresentable
    ) throws {
        try self.init(method: method, uri: uri, version: version, headers: headers, body: body.makeBody())
    }
}
