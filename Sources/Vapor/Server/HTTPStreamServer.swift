#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


// MARK: Byte => Character
extension Character {
    init(_ byte: Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}

class HTTPStreamServer<StreamType: HTTPStream>: Server {
    var stream: StreamType
    var delegate: Responder!

    func serve(_ responder: Responder, on host: String, at port: Int) throws {
        self.delegate = responder

        try stream.bind(to: host, on: port)
        try stream.listen()

        do {
            try stream.accept(max: Int(SOMAXCONN), handler: self.handle)
        } catch {
            Log.error("Failed to accept: \(socket) error: \(error)")
        }
    }

    init() {
        self.stream = StreamType.makeStream()
    }

    func halt() {
        stream.close()
    }

    private func handle(socket: HTTPStream) {
        var keepAlive = false

        repeat {
            let request: Request
            do {
                request = try socket.receive()
            } catch {
                Log.error("Error receiving request: \(error)")
                return
            }

            let response: Response
            do {
                response = try self.delegate.respond(request)
            } catch {
                Log.error("Error parsing response: \(error)")
                return
            }

            do {
                try socket.send(response, keepAlive: keepAlive)
            } catch {
                Log.error("Error sending response: \(error)")
            }

            keepAlive = request.supportsKeepAlive
        } while keepAlive && !socket.closed

        socket.close()
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
