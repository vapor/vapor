import Async
import Bits
import JunkDrawer

/// An HTTP client wrapped around TCP client
///
/// Can handle a single `Request` at a given time.
///
/// Multiple requests at the same time are subject to unknown behaviour
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/client/)
public final class HTTPClient {
    /// Serializes requests into byte buffers.
    private let serializerStream: HTTPSerializerStream<HTTPRequestSerializer>

    /// Parses byte buffers into responses.
    private let parserStream: HTTPParserStream<HTTPResponseParser>

    /// Inverse stream, takes in responses and outputs requests
    private let clientStream: HTTPClientStream

    /// Creates a new Client wrapped around a `TCP.Client`
    public init<ByteStream>(byteStream: ByteStream, maxResponseSize: Int = 10_000_000)
        where ByteStream: Stream, ByteStream.Input == ByteBuffer, ByteStream.Output == ByteBuffer
    {
        self.serializerStream = HTTPRequestSerializer().stream()
        self.parserStream = HTTPResponseParser(maxSize: maxResponseSize).stream()
        self.clientStream = .init()

        byteStream
            .stream(to: parserStream)
            .stream(to: clientStream)
            .stream(to: serializerStream)
            .output(to: byteStream)
    }

    /// Sends an HTTP request.
    public func send(_ request: HTTPRequest) -> Future<HTTPResponse> {
        let promise = Promise(HTTPResponse.self)
        clientStream.requestQueue.insert(request, at: 0)
        clientStream.responseQueue.insert(promise, at: 0)
        clientStream.upstream?.request()
        clientStream.update()
        return promise.future
    }
}
