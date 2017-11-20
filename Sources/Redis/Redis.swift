import Async
import Bits
import Dispatch
import Foundation
import TCP

/// A Redis client
///
/// Wraps around the provided Connection/Closable Binary Stream
public final class RedisClient: ClosableStream {
    public var errorStream: BaseStream.ErrorHandler?
    public var onClose: ClosableStream.CloseHandler?
    fileprivate let socketClose: ()->()
    
    public func close() {
        socketClose()
    }
    
    /// Parses redis data from binary
    let dataParser = DataParser()
    
    /// Serializes redis data to binary
    let dataSerializer = DataSerializer()
    
    /// Keeps track of whether this client is currently subscribed to a channel
    var isSubscribed = false
    
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
        
        dataParser.responseQueue.append(promise)
        
        let arguments = arguments ?? []
        let command = RedisData.array([.bulkString(command)] + arguments)
        
        dataSerializer.inputStream(command)
        
        return promise.future
    }
    
    /// Creates a pipeline and returns it.
    func makePipeline() -> Pipeline {
        return Pipeline(self)
    }
    
    /// Creates a new Redis client on the provided connection
    public init<DuplexByteStream: Async.Stream>(socket: DuplexByteStream) where DuplexByteStream.Input == ByteBuffer, DuplexByteStream.Output == ByteBuffer, DuplexByteStream: ClosableStream {
        socketClose = socket.close
        
        socket.catch { error in
            self.errorStream?(error)
            self.socketClose()
        }
        
        dataSerializer.drain(into: socket)
        socket.drain(into: dataParser)
    }
}

extension RedisClient {
    /// Connects to `Redis` using on a TCP socket to the provided hostname and port
    ///
    /// Listens to the socket using the provided `DispatchQueue`
    public static func connect(hostname: String = "localhost", port: UInt16 = 6379, worker: Worker) throws -> Future<RedisClient> {
        let socket = try TCP.Socket()
        try socket.connect(hostname: hostname, port: port)
        
        return socket.writable(queue: worker.eventLoop.queue).map { _ in
            let client = TCPClient(socket: socket, worker: worker)
            client.start()
            
            return RedisClient(socket: client)
        }
    }
}
