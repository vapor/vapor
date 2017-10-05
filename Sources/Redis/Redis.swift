import Async
import Bits
import Core
import Dispatch
import TCP

/// A Redis client
///
/// Wraps around the provided Connection/Closable Binary Stream
public final class Client<Connection: Async.Stream> where Connection.Input == ByteBuffer, Connection.Output == ByteBuffer, Connection: ClosableStream {
    /// The closable binary stream that this client runs on
    let socket: Connection
    
    /// Parses values from binary
    let valueParser = ValueParser()
    
    /// Serializes value to binary
    let valueSerializer = ValueSerializer()
    
    /// The maximum size of a single response. Prevents excessive memory usage
    public var maximumResponseSize: Int {
        get {
            return valueParser.maximumResponseSize
        }
        set {
            valueParser.maximumResponseSize = newValue
        }
    }
    
    /// Runs a Value as a command
    ///
    /// - returns: A future containing the server's response
    /// - throws: On network error
    public func runCommand(_ command: RedisValue) throws -> Future<RedisValue> {
        let promise = Promise<_RedisValue>()
        
        valueParser.responseQueue.append(promise)
        valueSerializer.inputStream(command)
        
        return promise.future.map { result in
            guard case .parsed(let value) = result else {
                throw ClientError.parsingError
            }
            
            return value
        }
    }
    
    /// Creates a new Redis client on the provided connection
    public init(socket: Connection) {
        self.socket = socket
        
        socket.errorStream = { _ in
            socket.close()
        }
        
        valueSerializer.drain(into: socket)
        socket.drain(into: valueParser)
    }
}

/// Connects to `Redis` using on a TCP socket to the provided hostname and port
///
/// Listens to the socket using the provided `DispatchQueue`
public func connect(hostname: String = "localhost", port: UInt16 = 6379, worker: Worker) throws -> Future<Client<TCPClient>> {
    let socket = try TCP.Socket()
    try socket.connect(hostname: hostname, port: port)
    
    return socket.writable(queue: worker.queue).map { _ in
        let client = TCPClient(socket: socket, worker: worker)
        client.start()
        
        return Client<TCPClient>(socket: client)
    }
}

