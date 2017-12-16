import Async
import Dispatch

/// A stream containing an  responder.
public final class ResponderStream: TransformingStream {
    /// See InputStream.Input
    public typealias Input = HTTPRequest

    /// See OutputStream.Output
    public typealias Output = HTTPResponse

    /// The base responder
    private let responder: Responder

    /// Worker to pass onto incoming requests
    public let container: Container

    /// Upstream HTTPRequest output stream
    public var upstream: ConnectionContext?

    /// Downstream HTTPResponse input stream
    public var downstream: AnyInputStream<HTTPResponse>?

    /// Create a new response stream.
    /// The responses will be awaited on the supplied queue.
    public init(responder: Responder, using container: Container) {
        self.responder = responder
        self.container = container
    }

    /// See TransformingStream.transform
    public func transform(_ httpRequest: HTTPRequest) -> Future<HTTPResponse> {
        return Future {
            let req = Request(http: httpRequest, using: self.container)
            return try self.responder.respond(to: req)
                .map(to: HTTPResponse.self) { $0.http }
        }
    }
}
