import Async
import Bits
import Dispatch
import Foundation
import TCP

/// A Redis client
///
/// Wraps around the provided Connection/Closable Binary Stream
public final class RedisClient: Async.Stream {
    /// See InputStream.Input
    public typealias Input = RedisData

    /// See OutputStream.RedisData
    public typealias Output = RedisData
    
    /// Parses redis data from binary
    internal let dataParser = DataParser()
    
    /// Serializes redis data to binary
    internal let dataSerializer = DataSerializer()
    
    /// Keeps track of whether this client is currently subscribed to a channel
    internal var isSubscribed = false

    /// A set of promises awaiting a response
    internal var responseQueue = [Promise<RedisData>]()

    /// Use a basic output stream to implement client output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// The socket we are connected to
    private let socket: ClosableStream

    /// Creates a new Redis client on the provided connection
    public init<ByteStream>(socket: ByteStream)
        where ByteStream: Async.Stream,
            ByteStream.Input == ByteBuffer,
            ByteStream.Output == ByteBuffer
    {
        self.socket = socket

        /// the data serializer stream should
        /// write directly to the socket
        dataSerializer.stream(to: socket)

        /// the socket stream should parse the data
        /// then drain into our internal logic
        socket.stream(to: dataParser).drain { output in
            if self.responseQueue.count > 0 {
                /// we have a promise queued, complete it
                self.responseQueue.removeFirst().complete(output)
            } else {
                /// just send to output stream
                self.outputStream.onInput(output)
            }
        }.catch(onError: self.onError)
    }

    /// The maximum size of a single response. Prevents excessive memory usage
    public var maximumResponseSize: Int {
        get {
            return dataParser.maximumResponseSize
        }
        set {
            dataParser.maximumResponseSize = newValue
        }
    }

    /// Runs a Value as a command
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/redis/custom-commands/#usage)
    ///
    /// - returns: A future containing the server's response or the error
    public func run(command: String, arguments: [RedisData]? = nil) -> Future<RedisData> {
        if isSubscribed {
            return Future(error: RedisError(.cannotReuseSubscribedClients))
        }
        let promise = Promise<RedisData>()
        responseQueue.append(promise)

        let arguments = arguments ?? []
        let command = RedisData.array([.bulkString(command)] + arguments)
        dataSerializer.onInput(command)

        return promise.future
    }

    /// InputStream.onInput
    public func onInput(_ input: RedisData) {
        dataSerializer.onInput(input)
    }

    /// InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// Creates a pipeline and returns it.
    public func makePipeline() -> RedisPipeline {
        return RedisPipeline(self)
    }

    /// See CloseableStream.close
    public func close() {
        outputStream.close()
        outputStream = .init()
        socket.close()
    }
}

extension RedisClient {
    /// Connects to `Redis` using on a TCP socket to the provided hostname and port
    ///
    /// Listens to the socket using the provided `DispatchQueue`
    public static func connect(
        hostname: String = "localhost",
        port: UInt16 = 6379,
        on worker: Worker
    ) throws -> Future<RedisClient> {
        let socket = try TCPSocket()
        try socket.connect(hostname: hostname, port: port)
        
        return socket.writable(queue: worker.eventLoop.queue).map { _ in
            let client = TCPClient(socket: socket, worker: worker)
            client.start()
            
            return RedisClient(socket: client)
        }
    }
}
