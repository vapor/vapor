#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import S4

public class Jeeves<Socket where Socket: Vapor.Socket, Socket: Hashable>: S4.Server {
    
    // MARK: Sockets
    private var streamSocket: Socket?
    private var activeSockets = ThreadSafeSocketStore<Socket>()


    // MARK: S4.Server
    public var ip: String?
    public var delegate: S4.Responder!
    
    public func serve(responder: Responder, at port: Port) throws {
        halt()
        self.delegate = responder
        
        streamSocket = try Socket.makeSocket()
        try streamSocket?.bind(toAddress: ip, onPort: "\(port)")
        try streamSocket?.listen(pendingConnectionBacklog: 100)

        do {
            try self.streamSocket?.accept(Int(SOMAXCONN), connectionHandler: self.handle)
        } catch {
            Log.error("Failed to accept: \(self.streamSocket) error: \(error)")
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

    private func handle(socket: Socket) {
        do {
            try Background {
                self.activeSockets.insert(socket)
                defer {
                    self.activeSockets.remove(socket)
                }

                do {
                    var keepAlive = false
                    repeat {
                        let request = try socket.readRequest()
                        let response = try self.delegate.respond(request)
                        
                        try socket.write(response, keepAlive: keepAlive)
                        //FIXME: keep alive
                        keepAlive = request.supportsKeepAlive
                    } while keepAlive

                    try socket.close()
                } catch {
                    Log.error("Request Handle Failed: \(error)")
                }
            }
        } catch {
            Log.error("Backgrounding Handler Failed: \(error)")
        }
    }


}

extension Request {
    var supportsKeepAlive: Bool {
        for value in headers["Connection"] ?? [] {
            if value.trim() == "keep-alive" {
                return true
            }
        }
        return false
    }
}

extension Response {
    static func notFound() -> Response {
        return Response(error: "Not Found")
    }
}
