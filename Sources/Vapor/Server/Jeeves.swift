
import Foundation

public class Jeeves<Socket: Vapor.Socket>: ServerDriver {
    
    // MARK: Delegate
    
    public var delegate: ServerDriverDelegate?
    
    // MARK: Sockets
    
    private var streamSocket: Socket?
    private var activeSockets = ThreadSafeSocketStore()
    
    // MARK: Init
    
    public init() {}
    
    // MARK: ServerDriver
    
    public func boot(port port: Int) throws {
        halt()
        streamSocket = try Socket.streamSocket()
        
        let p = Process.valueFor(argument: "port") ?? "\(port)"
        let a = Process.valueFor(argument: "ip") ?? "0.0.0.0"
        try streamSocket?.bind(a, port: p)
        try streamSocket?.listen(100)
        
        Background {
            do {
                try self.streamSocket?.accept(self.handle)
            } catch {
                Log.error("Failed to accept: \(self.streamSocket) error: \(error)")
            }
        }
    }
    
    public func halt() {
        activeSockets.forEach { socket in
            // Individually so one failure doesn't prevent others from running
            do {
                try socket.close()
            } catch {
                Log.error("Failed to close active socket: \(socket) error: \(error)")
            }
        }
        activeSockets = ThreadSafeSocketStore()
        
        do {
            try streamSocket?.close()
        } catch {
            Log.error("Failed to halt: \(streamSocket) error: \(error)")
        }
    }
    
    private func handle(socket: Vapor.Socket) {
        activeSockets.insert(socket)
        defer {
            activeSockets.remove(socket)
        }
        
        do {
            var keepAlive = false
            repeat {
                let request = try socket.readRequest()
                let response = delegate?.serverDriverDidReceiveRequest(request) ?? Response.notFound()
                try socket.write(response)
                keepAlive = request.supportsKeepAlive
            } while keepAlive
            
            try socket.close()
        } catch {
            Log.error("Request Handle Failed: \(error)")
        }
    }
}

extension Response {
    static func notFound() -> Response {
        return Response(error: "Not Found")
    }
}
