import Async
import Bits

/// Accepts a stream of byte streams converting them to client stream.
internal final class HTTPServerStream<ByteStream, Responder>: InputStream
    where ByteStream: Stream,
    ByteStream.Input == ByteBuffer,
    ByteStream.Output == ByteBuffer,
    Responder: Async.Stream,
    Responder.Input == HTTPRequest,
    Responder.Output == HTTPResponse
{
    /// See InputStream.Input
    typealias Input = ByteStream

    /// See OutputStream.Output
    typealias Output = ByteStream

    /// The upstream accept stream
    private var upstream: ConnectionContext?

    /// Responder factory
    private let responderFactory: HTTPServer<ByteStream, Responder>.ResponderFactory

    /// Create a new HTTP server stream.
    init<AcceptStream>(
        acceptStream: AcceptStream,
        responderFactory: @escaping HTTPServer<ByteStream, Responder>.ResponderFactory
    )
        where AcceptStream: OutputStream,
        AcceptStream.Output == ByteStream
    {
        self.responderFactory = responderFactory
        acceptStream.output(to: self)
    }

    /// See InputStream.input
    func input(_ event: InputEvent<ByteStream>) {
        switch event {
        case .connect(let upstream):
            /// never stop accepting
            upstream.request(count: .max)
        case .next(let byteStream):
            let serializerStream = HTTPResponseSerializer().stream()
            let parserStream = HTTPRequestParser(maxSize: 10_000_000).stream()

            byteStream
                .stream(to: parserStream)
                .stream(to: responderFactory(byteStream))
                .map { response -> HTTPResponse in
                    /// map the responder adding http upgrade support
                    defer {
                        if let onUpgrade = response.onUpgrade {
                            onUpgrade.closure(AnyStream(byteStream))
                        }
                    }
                    return response
                }
                .stream(to: serializerStream)
                .output(to: byteStream)
        case .error(let error): print(error)
        case .close: print("accept stream closed")
        }
    }
}
