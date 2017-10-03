import Async
import Bits
import TCP
import Dispatch

public final class Redis<Connection: Async.Stream> where Connection.Input == ByteBuffer, Connection.Output == ByteBuffer, Connection: ClosableStream {
    let socket: Connection
    
    public init(socket: Connection) {
        self.socket = socket
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

