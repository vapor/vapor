import Dispatch
import Service

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
public final class Response: SubContainer, CustomStringConvertible, CustomDebugStringConvertible {
    // MARK: Stored

    /// The wrapped `HTTPResponse`.
    ///
    ///     print(res.http.status) // 200 OK
    ///
    public var http: HTTPResponse

    /// This `Response`'s parent container. This is normally the event loop. The `Response` will redirect
    /// all calls to create services to this container.
    public let superContainer: Container

    /// This response's private container.
    public let privateContainer: SubContainer

    // MARK: Computed

    /// See `CustomStringConvertible.description
    public var description: String {
        return http.description
    }

    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        return http.debugDescription
    }
    /// The response's event loop container.
    /// note: convenience name for `.superContainer`
    public var worker: Container {
        return superContainer
    }

    /// Helper for encoding and decoding `Content` from an HTTP message.
    ///
    /// This helpper can encode data to the HTTP message. Uses the Content's default media type if none is supplied.
    ///
    ///     try res.content.encode(user)
    ///
    /// This helper can also _decode_ data from the HTTP message.
    ///
    ///     let user = try res.content.decode(User.self)
    ///     print(user) /// Future<User>
    ///
    /// See `ContentContainer` methods for more information.
    public var content: ContentContainer {
        return ContentContainer(container: self, body: http.body, mediaType: http.mediaType) { body, mediaType in
            self.http.body = body
            self.http.mediaType = mediaType
        }
    }

    /// Create a new `Response`.
    public init(http: HTTPResponse = .init(), using container: Container) {
        self.http = http
        self.superContainer = container
        self.privateContainer = container.subContainer(on: container)
    }

    // MARK: Methods

    /// Creates a `Request` on the same container as this `Response`.
    public func makeRequest() -> Request {
        return Request(using: superContainer)
    }
}
