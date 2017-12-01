import Async
import Foundation
import Service

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
public struct HTTPResponse: HTTPMessage {
    /// See Message.version
    public var version: HTTPVersion

    /// HTTP response status code.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/status/)
    public var status: HTTPStatus

    /// See Message.headers
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/headers/)
    public var headers: HTTPHeaders

    /// See Message.body
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
    public var body: HTTPBody

<<<<<<< HEAD
    /// See Message.onUpgrade
    public var onUpgrade: HTTPOnUpgrade?

    /// Create a new HTTP response.
    public init(
        version: HTTPVersion = HTTPVersion(major: 1, minor: 1),
        status: HTTPStatus = .ok,
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBody = HTTPBody()
=======
    /// See Extendable.extend
    public var extend: Extend
    
    /// The super container in which this Response is used
    var context: BasicContext
    
    /// See `Container.config`
    public var config: Config {
        return context.config
    }
    
    /// See `Container.environment`
    public var environment: Environment {
        return context.environment
    }
    
    /// See `Container.services`
    public var services: Services {
        return context.services
    }

    /// Create a new HTTP response.
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: Body = Body(),
        context: Context = BasicContext()
>>>>>>> 503de6b06912672ed95565679354d11171f72740
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body
<<<<<<< HEAD
=======
        self.extend = Extend()
        self.context = .boxing(context)
        Response.onInit?(self)
>>>>>>> 503de6b06912672ed95565679354d11171f72740
    }

}

extension HTTPResponse {
    /// Create a new HTTP response using something BodyRepresentable.
<<<<<<< HEAD
    public init(
        version: HTTPVersion = HTTPVersion(major: 1, minor: 1),
        status: HTTPStatus = .ok,
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBodyRepresentable
=======
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: BodyRepresentable,
        context: Context = BasicContext()
>>>>>>> 503de6b06912672ed95565679354d11171f72740
    ) throws {
        try self.init(version: version, status: status, headers: headers, body: body.makeBody(), context: context)
    }
}
