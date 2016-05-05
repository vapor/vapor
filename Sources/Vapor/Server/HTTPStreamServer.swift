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

final class HTTPStreamServer<StreamType: HTTPListenerStream>: Server {
    var stream: StreamType!
    var delegate: Responder!

    required init(host: String, port: Int, responder: Responder) throws {
        stream = try StreamType(address: host, port: port)
        delegate = responder
    }

    func start() throws {
        try stream.bind()
        try stream.listen()

        do {
            try stream.accept(max: Int(SOMAXCONN), handler: self.handle)
        } catch {
            Log.error("Failed to accept: \(socket) error: \(error)")
        }
    }

    func halt() {
        do {
            try stream.close()
        } catch {
            Log.error("Failed to close stream: \(error)")
        }
    }

    private func handle(socket: HTTPStream) {
        var keepAlive = false

        repeat {
            let request: Request
            do {
                request = try socket.receive()
            } catch let error as HTTPStreamError where error.isClosedByPeer {
                Log.debug("Remote peer has closed connection")
                return
            } catch {
                Log.error("Error receiving request: \(error)")
                return
            }

            let response: Response
            do {
                response = try self.delegate.respond(to: request)
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

        do {
            try socket.close()
        } catch {
            Log.error("Failed to close stream: \(error)")
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
