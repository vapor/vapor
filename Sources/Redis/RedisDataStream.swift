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
    private var drainedResponses = 0
    
    private var requests = [RedisData]()
    private var drainedRequests = 0

    /// Parses redis data from binary
    let parser: RedisDataParser

    /// Serializes redis data to binary
    private let serializer: RedisDataSerializer

    /// Downstream redis data input stream
    private var downstream: AnyInputStream<Output>?

    /// Serialized requests
    var remainingDownstreamRequests: UInt

    /// Upstream redis data output stream
    private var upstream: ConnectionContext?

    /// Creates a new redis data stream.
    internal init<SourceStream, SinkStream>(
        source: SourceStream,
        sink: SinkStream
    ) where
        SourceStream: OutputStream,
        SinkStream: InputStream,
        SinkStream.Input == ByteBuffer,
        SourceStream.Output == ByteBuffer
    {
        parser = .init()
        serializer = .init()
        remainingDownstreamRequests = 0
        responseQueue = []
        source
            .stream(to: parser)
            .stream(to: self)
            .stream(to: serializer)
            .output(to: sink)
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
            if responseQueue.count > drainedResponses {
                responseQueue[drainedResponses].complete(input)
                drainedResponses += 1
            } else {
                flushBacklog()
            }
            
            responseQueue.removeFirst(drainedResponses)
            drainedResponses = 0
        case .error(let error): downstream?.error(error)
        case .close: downstream?.close()
        }
    }

    /// See ConnectionContext.connection
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            remainingDownstreamRequests += count
            
            flushBacklog()
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
        
        flush(request)
        responseQueue.append(promise)
        
        upstream?.request()
        
        return promise.future
    }
    
    func flushBacklog() {
        while requests.count > drainedRequests, remainingDownstreamRequests > 0 {
            serializer.next(requests[drainedRequests])
            
            drainedRequests += 1
            remainingDownstreamRequests -= 1
        }
        
        requests.removeFirst(drainedRequests)
        self.drainedRequests = 0
    }

    /// Updates the stream's state. If there are outstanding
    /// downstream requests, they will be fulfilled.
    private func flush(_ request: RedisData) {
        flushBacklog()
        
        guard remainingDownstreamRequests > 0 else {
            requests.append(request)
            return
        }
        
        serializer.next(request)
    }
}
