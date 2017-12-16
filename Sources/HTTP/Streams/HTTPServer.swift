import Async
import Bits
import TCP

/// Converts an output stream of byte streams (meta stream) to
/// a stream of HTTP clients. These incoming clients are then
/// streamed to the responder supplied during `.start()`.
public final class HTTPServer<AcceptStream, Worker>
    where AcceptStream: OutputStream,
    AcceptStream.Output: ByteStreamRepresentable,
    Worker: HTTPResponder,
    Worker: Worker
{
    /// The underlying server stream.
    private let serverStream: HTTPServerStream<AcceptStream, Worker>

    /// Handles any uncaught errors
    public typealias ErrorHandler = (Error) -> ()

    /// Sets this servers error handler.
    public var onError: ErrorHandler? {
        get { return serverStream.onError }
        set { serverStream.onError = newValue}
    }

    /// Create a new HTTP server with the supplied accept stream.
    public init(acceptStream: AcceptStream, workers: [Worker]) {
        self.serverStream = HTTPServerStream(
            acceptStream: acceptStream,
            workers: workers
        )
    }
}

/// Representable by an associated byte stream.
public protocol ByteStreamRepresentable {
    /// The associated byte stream type.
    associatedtype ByteStream
        where ByteStream: Stream,
            ByteStream.Input == ByteBuffer,
            ByteStream.Output == ByteBuffer

    /// Convert to the associated byte stream.
    func stream(on Worker: Worker) -> ByteStream
}

extension TCPClient: ByteStreamRepresentable {}
