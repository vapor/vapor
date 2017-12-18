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
    Worker: Async.Worker
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
    associatedtype SourceStream
        where
            SourceStream: OutputStream,
            SourceStream.Output == ByteBuffer

    associatedtype SinkStream
        where
            SinkStream: InputStream,
            SinkStream.Input == ByteBuffer

    /// Convert to the associated byte stream.
    func source(on worker: Worker) -> SourceStream
    func sink(on worker: Worker) -> SinkStream
}

extension TCPClient: ByteStreamRepresentable {
    /// See ByteStreamRepresentable.source
    public func source(on eventLoop: Worker) -> SocketSource<TCPSocket> {
        return socket.source(on: eventLoop.eventLoop)
    }

    /// See ByteStreamRepresentable.sink
    public func sink(on eventLoop: Worker) -> SocketSink<TCPSocket> {
        return socket.sink(on: eventLoop.eventLoop)
    }
}
