import Async
import Service
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
<<<<<<< HEAD
    public var body: HTTPBody

    /// See Message.onUpgrade
    public var onUpgrade: HTTPOnUpgrade?
=======
    public var body: Body
    
    /// See `Extendable.extend`
    public var extend: Extend
    
    /// The super container in which this Request is used
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
>>>>>>> 503de6b06912672ed95565679354d11171f72740

    /// Create a new HTTP request.
    public init(
        method: HTTPMethod = .get,
        uri: URI = URI(),
<<<<<<< HEAD
        version: HTTPVersion = HTTPVersion(major: 1, minor: 1),
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBody = HTTPBody()
=======
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: Body = Body(),
        context: Context = BasicContext()
>>>>>>> 503de6b06912672ed95565679354d11171f72740
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
<<<<<<< HEAD
=======
        self.extend = Extend()
        self.context = .boxing(context)
        Request.onInit?(self)
    }

    /// Called when request is deinitializing
    deinit {
        Request.onDeinit?(self)
        // print("Request.deinit")
>>>>>>> 503de6b06912672ed95565679354d11171f72740
    }
}

// MARK: Convenience

extension HTTPRequest {
    /// Create a new HTTP request using something BodyRepresentable.
    public init(
        method: HTTPMethod = .get,
        uri: URI = URI(),
<<<<<<< HEAD
        version: HTTPVersion = HTTPVersion(major: 1, minor: 1),
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBodyRepresentable
=======
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: BodyRepresentable,
        context: Context = BasicContext()
>>>>>>> 503de6b06912672ed95565679354d11171f72740
    ) throws {
        try self.init(method: method, uri: uri, version: version, headers: headers, body: body.makeBody(), context: context)
    }
}
