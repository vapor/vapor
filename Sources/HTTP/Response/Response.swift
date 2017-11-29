import Async
import Foundation

/// An HTTP response.
///
/// Used to respond to a request from an HTTP client.
///
///     200 OK HTTP/1.1
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
///     let res = Response(status: .ok, body: "hello")
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/)
public struct HTTPResponse: Message {
    /// See Message.version
    public var version: Version

    /// HTTP response status code.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/status/)
    public var status: Status

    /// See Message.headers
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/headers/)
    public var headers: Headers

    /// See Message.body
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
    public var body: Body

    /// See Message.onUpgrade
    public var onUpgrade: OnUpgrade?

    /// Create a new HTTP response.
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: Body = Body()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body
    }

}

extension HTTPResponse {
    /// Create a new HTTP response using something BodyRepresentable.
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: BodyRepresentable
    ) throws {
        try self.init(version: version, status: status, headers: headers, body: body.makeBody())
    }
}
