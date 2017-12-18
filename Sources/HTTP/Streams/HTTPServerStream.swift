import Async
import Bits

/// Accepts a stream of byte streams converting them to client stream.
internal final class HTTPServerStream<AcceptStream, Worker>: InputStream
    where AcceptStream: OutputStream,
    AcceptStream.Output: ByteStreamRepresentable,
    Worker: HTTPResponder,
    Worker: Async.Worker
{
    /// See InputStream.Input
    typealias Input = AcceptStream.Output

    /// Handles errors
    internal var onError: HTTPServer<AcceptStream, Worker>.ErrorHandler?

    /// The upstream accept stream
    private var upstream: ConnectionContext?

    /// HTTP responder
    private let workers: [Worker]

    /// The current worker.
    /// A new worker is chosen (round robin) for each connection.
    private var workerOffset: Int

    /// Create a new HTTP server stream.
    init(
        acceptStream: AcceptStream,
        workers: [Worker]
    ) {
        self.workers = workers
        workerOffset = 0
        acceptStream.output(to: self)
    }

    /// See InputStream.input
    func input(_ event: InputEvent<AcceptStream.Output>) {
        switch event {
        case .connect(let upstream):
            /// never stop accepting
            upstream.request(count: .max)
        case .next(let input):
            let serializerStream = HTTPResponseSerializer().stream()
            let parserStream = HTTPRequestParser(maxSize: 10_000_000).stream()

            let worker: Worker
            workerOffset += 1
            if workerOffset >= workers.count {
                workerOffset = 0
            }
            worker = workers[workerOffset]

            let source = input.source(on: worker)
            let sink = input.sink(on: worker)
            source
                .stream(to: parserStream)
                .stream(to: worker.stream(on: worker))
                .map(to: HTTPResponse.self) { response in
                    /// map the responder adding http upgrade support
                    defer {
                        if let onUpgrade = response.onUpgrade {
                            onUpgrade.closure(.init(source), .init(sink))
                        }
                    }
                    return response
                }
                .stream(to: serializerStream)
                .output(to: sink)
        case .error(let error):
            onError?(error)
        case .close: print("accept stream closed")
        }
    }
}
