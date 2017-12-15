import Async
import Bits
import TCP

/// Converts an output stream of byte streams (meta stream) to
/// a stream of HTTP clients. These incoming clients are then
/// streamed to the responder supplied during `.start()`.
public final class HTTPServer<ByteStream, Responder>
    where ByteStream: Stream,
        ByteStream.Input == ByteBuffer,
        ByteStream.Output == ByteBuffer,
        Responder: Async.Stream,
        Responder.Input == HTTPRequest,
        Responder.Output == HTTPResponse
{
    /// The underlying server stream.
    private let serverStream: HTTPServerStream<ByteStream, Responder>

    /// The HTTP server users the supplied responder closure to
    /// create responder streams for incoming clients.
    public typealias ResponderFactory = (ByteStream) -> (Responder)

    /// Create a new HTTP server with the supplied accept stream.
    public init<AcceptStream>(acceptStream: AcceptStream, responderFactory: @escaping ResponderFactory)
        where AcceptStream: OutputStream,
            AcceptStream.Output == ByteStream
    {
        self.serverStream = HTTPServerStream(
            acceptStream: acceptStream,
            responderFactory: responderFactory
        )
    }
}
