import Async
import Bits
import TCP
import Dispatch

public final class Redis<Connection: Async.Stream> where Connection.Input == ByteBuffer, Connection.Output == ByteBuffer, Connection: ClosableStream {
    let socket: Connection
    
    let responseParser = ResponseParser()
    let requestSerializer = RequestSerializer()
    
    public var maximumRepsonseSize: Int {
        get {
            return responseParser.maximumRepsonseSize
        }
        set {
            responseParser.maximumRepsonseSize = newValue
        }
    }
    
    public func runCommand(_ command: RedisValue) throws -> Future<RedisValue> {
        let promise = Promise<_RedisValue>()
        
        responseParser.responseQueue.append(promise)
        requestSerializer.inputStream(command)
        
        return promise.future.map { result in
            guard case .parsed(let value) = result else {
                throw ClientError.parsingError
            }
            
            return value
        }
    }
    
    public init(socket: Connection) {
        self.socket = socket
        
        socket.errorStream = { _ in
            socket.close()
        }
        
        requestSerializer.drain(into: socket)
        socket.drain(into: responseParser)
    }
}

extension Redis {
    public static func connect(hostname: String, port: UInt16 = 6379, queue: DispatchQueue) throws -> Future<Redis<TCP.Client>> {
        let socket = try TCP.Socket()
        try socket.connect(hostname: hostname, port: port)
        
        return socket.writable(queue: queue).map { _ in
            let client = TCP.Client(socket: socket, queue: queue)
            client.start()
            
            return Redis<TCP.Client>(socket: client)
        }
    }
}

