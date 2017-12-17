import Async
import Bits

/// An inverse client stream accepting responses and outputting requests.
/// Used to implement HTTPClient. Should be kept internal
internal final class HTTPClientStream<ByteStream>: Stream, ConnectionContext
    where ByteStream: Stream,
    ByteStream.Input == ByteBuffer,
    ByteStream.Output == ByteBuffer
{
    /// See InputStream.Input
    typealias Input = HTTPResponse

    /// See OutputStream.Output
    typealias Output = HTTPRequest

    /// Queue of promised responses
    var responseQueue: [Promise<HTTPResponse>]

    /// Queue of requests to be serialized
    var requestQueue: [HTTPRequest]

    /// Accepts serialized requests
    var downstream: AnyInputStream<Output>?

    /// Serialized requests
    var remainingDownstreamRequests: UInt

    /// Parsed responses
    var upstream: ConnectionContext?

    /// The source bytestream
    let byteStream: ByteStream

    /// Creates a new HTTP client stream
    init(byteStream: ByteStream, maxResponseSize: Int = 10_000_000) {
        self.responseQueue = []
        self.requestQueue = []
        self.remainingDownstreamRequests = 0
        self.byteStream = byteStream

        let serializerStream = HTTPRequestSerializer().stream()
        let parserStream = HTTPResponseParser(maxSize: maxResponseSize).stream()

        byteStream
            .stream(to: parserStream)
            .stream(to: self)
            .stream(to: serializerStream)
            .output(to: byteStream)
    }

    /// Updates the stream's state. If there are outstanding
    /// downstream requests, they will be fulfilled.
    func update() {
        guard remainingDownstreamRequests > 0 else {
            return
        }
        while let request = requestQueue.popLast() {
            remainingDownstreamRequests -= 1
            downstream?.next(request)
        }
    }

    /// See ConnectionContext.connection
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            let isSuspended = remainingDownstreamRequests == 0
            remainingDownstreamRequests += count
            if isSuspended { update() }
        case .cancel:
            /// FIXME: better cancel support
            remainingDownstreamRequests = 0
        }
    }

    /// See OutputStream.output
    func output<S>(to inputStream: S) where S : InputStream, S.Input == HTTPRequest {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See InputStream.input
    func input(_ event: InputEvent<HTTPResponse>) {
        switch event {
        case .connect(let upstream):
            self.upstream = upstream
        case .next(let input):
            let promise = responseQueue.popLast()!
            promise.complete(input)
            if let onUpgrade = input.onUpgrade {
                onUpgrade.closure(AnyStream(byteStream))
            }
            update()
        case .error(let error): downstream?.error(error)
        case .close: downstream?.close()
        }
    }
}
