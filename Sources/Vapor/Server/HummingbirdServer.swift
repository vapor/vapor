#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Hummingbird




// MARK: Byte => Character
extension Character {
    init(_ byte: Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}

public class HummingbirdServer: Server {

    // MARK: Sockets
    private var socket: Hummingbird.Socket?
    //private var activeSockets = ThreadSafeSocketStore<Socket>()


    // MARK: S4.Server
    public var ip: String?
    public var delegate: Responder!

    public func serve(responder: Responder, at port: Int) throws {
        halt()
        self.delegate = responder

        let socket = try Hummingbird.Socket.makeStreamSocket()
        try socket.bind(toAddress: ip, onPort: "\(port)")
        try socket.listen(pendingConnectionBacklog: 100)

        self.socket = socket

        do {
            try socket.accept(Int(SOMAXCONN), connectionHandler: self.handle)
        } catch {
            Log.error("Failed to accept: \(socket) error: \(error)")
        }
    }

    public func halt() {
        socket?.close()
    }

    private func handle(socket: Hummingbird.Socket) {
        do {
            try Background {
                do {
                    var keepAlive = false
                    repeat {
                        let request: Request = try socket.receive()
                        let response = try self.delegate.respond(request)
                        try socket.send(response, keepAlive: keepAlive)
                        keepAlive = request.supportsKeepAlive
                    } while keepAlive

                    socket.close()
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
