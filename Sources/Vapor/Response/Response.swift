/// `Response` is a service-container wrapper around an `HTTPResponse`.
///
/// Use this `Response` to access information about the `HTTPResponse` (`res.http`).
///
///     print(res.http.status) // 200 OK
///
/// You can also use `Response` to create services you may need while generating a response (`res.make(_:)`.
///
///     let client = try res.make(Client.self)
///     print(client) // Client
///     client.get("http://vapor.codes")
///
/// See `HTTPResponse` and `Container` for more information.
public final class Response: ContainerAlias, HTTPMessageContainer, ResponseCodable, CustomStringConvertible, CustomDebugStringConvertible {
    /// See `ContainerAlias`.
    public static let aliasedContainer: KeyPath<Response, Container> = \.sharedContainer

    // MARK: HTTP

    /// The wrapped `HTTPResponse`.
    ///
    ///     print(res.http.status) // 200 OK
    ///
    public var http: HTTPResponse

    // MARK: Services

    /// This `Response`'s parent container. This is normally the event loop. The `Response` will redirect
    /// all calls to create services to this container.
    public let sharedContainer: Container

    /// This response's private container.
    public let privateContainer: SubContainer

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

    /// Helper for encoding and decoding `Content` from an HTTP message.
    ///
    /// This helper can encode data to the HTTP message. Uses the Content's default media type if none is supplied.
    ///
    ///     try res.content.encode(user)
    ///
    /// This helper can also _decode_ data from the HTTP message.
    ///
    ///     let user = try res.content.decode(User.self)
    ///     print(user) /// Future<User>
    ///
    /// See `ContentContainer` methods for more information.
    public var content: ContentContainer<Response> {
        return ContentContainer(self)
    }

    // MARK: Init

    /// Create a new `Response`.
    public init(http: HTTPResponse = .init(), using container: Container) {
        self.http = http
        self.sharedContainer = container
        self.privateContainer = container.subContainer(on: container)
    }

    // MARK: Request

    /// Creates a `Request` on the same container as this `Response`.
    public func makeRequest() -> Request {
        return Request(using: sharedContainer)
    }

    // MARK: Codable

    /// See `ResponseDecodable`.
    public static func decode(from res: Response, for req: Request) throws -> EventLoopFuture<Response> {
        return req.eventLoop.newSucceededFuture(result: res)
    }

    /// See `ResponseEncodable`.
    public func encode(for req: Request) throws -> Future<Response> {
        return req.eventLoop.newSucceededFuture(result: self)
    }
}
