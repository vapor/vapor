import Async
import Bits

/// A stream of redis data.
final class RedisDataStream: Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = RedisData

    /// See OutputStream.RedisData
    typealias Output = RedisData

    /// A set of promises awaiting a response
    private var responseQueue: [Promise<RedisData>]

    /// A set of promises awaiting a response
    private var requestQueue: [RedisData]

    /// Parses redis data from binary
    private let parser: RedisDataParser

    /// Serializes redis data to binary
    private let serializer: RedisDataSerializer

    /// Downstream redis data input stream
    private var downstream: AnyInputStream<Output>?

    /// Serialized requests
    var remainingDownstreamRequests: UInt

    /// Upstream redis data output stream
    private var upstream: ConnectionContext?

    /// Creates a new redis data stream.
    internal init<ByteStream>(byteStream: ByteStream)
        where ByteStream: Async.Stream,
            ByteStream.Input == ByteBuffer,
            ByteStream.Output == ByteBuffer
    {
        parser = .init()
        serializer = .init()
        remainingDownstreamRequests = 0
        responseQueue = []
        requestQueue = []
        byteStream
            .stream(to: parser)
            .stream(to: self)
            .stream(to: serializer)
            .output(to: byteStream)
    }

    /// See OutputStream.output
    func output<S>(to inputStream: S) where S : InputStream, S.Input == RedisData {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See InputStream.input
    func input(_ event: InputEvent<RedisData>) {
        switch event {
        case .connect(let upstream):
            self.upstream = upstream
        case .next(let input):
            let promise = responseQueue.popLast()!
            promise.complete(input)
            update()
        case .error(let error): downstream?.error(error)
        case .close: downstream?.close()
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

    /// Enqueues a RedisData request to be sent over the pipeline.
    /// The returned future will contain the requests's associated
    /// response when it arrives.
    func enqueue(request: RedisData) -> Future<RedisData> {
        let promise = Promise(RedisData.self)
        requestQueue.insert(request, at: 0)
        responseQueue.insert(promise, at: 0)
        upstream?.request()
        update()
        return promise.future
    }

    /// Updates the stream's state. If there are outstanding
    /// downstream requests, they will be fulfilled.
    private func update() {
        guard remainingDownstreamRequests > 0 else {
            return
        }
        while let request = requestQueue.popLast() {
            remainingDownstreamRequests -= 1
            downstream?.next(request)
        }
    }
}
