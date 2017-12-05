
/// A stream containing an  responder.
public final class ResponderStream: Async.Stream {
    /// See InputStream.Input
    public typealias Input = HTTPRequest

    /// See OutputStream.Output
    public typealias Output = HTTPResponse

    /// The base responder
    private let responder: Responder

    /// Worker to pass onto incoming requests
    public let container: Container

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// Create a new response stream.
    /// The responses will be awaited on the supplied queue.
    public init(responder: Responder, using container: Container) {
        self.responder = responder
        self.outputStream = .init()
        self.container = container
    }

    /// See InputStream.onInput
    public func onInput(_ input: Input) {
        let req = Request(http: input, using: container)
        do {
            // dispatches the incoming request to the responder.
            // the response is awaited on the responder stream's queue.
            try responder.respond(to: req)
                .map { res in
                    return res.http
                }
                .stream(to: outputStream)
        } catch {
            self.onError(error)
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See CloseableStream.close
    public func close() {
        outputStream.close()
    }

    /// See CloseableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
}

