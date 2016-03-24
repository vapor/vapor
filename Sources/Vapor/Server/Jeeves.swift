#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public class Jeeves<Socket where Socket: Vapor.Socket, Socket: Hashable>: ServerDriver {

    // MARK: Delegate
    public var delegate: ServerDriverDelegate?

    // MARK: Sockets
    private var streamSocket: Socket?
    private var activeSockets = ThreadSafeSocketStore<Socket>()

    // MARK: Init
    public init() {}

    // MARK: ServerDriver
    public func boot(ip ip: String, port: Int) throws {
        halt()
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
                        let response = self.delegate?.serverDriverDidReceiveRequest(request) ?? Response.notFound()
                        try socket.write(response)
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

extension Response {
    static func notFound() -> Response {
        return Response(error: "Not Found")
    }
}
