#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Strand

// MARK: Byte => Character
extension Character {
    init(_ byte: Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}

final class StreamServer<
    Server: StreamDriver,
    Parser: StreamParser,
    Serializer: StreamSerializer
>: ServerDriver {
    var server: Server
    var responder: Responder

    required init(host: String, port: Int, responder: Responder) throws {
        server = try Server.make(host: host, port: port)
        self.responder = responder
    }

    func start() throws {
        do {
            try server.start(handler: handle)
        } catch {
            Log.error("Failed to start: \(error)")
        }
    }

    private func handle(_ stream: Stream) {
        do {
            _ = try Strand {
                self.parse(stream)
            }
        } catch {
            Log.error("Could not create thread: \(error)")
        }
    }

    private func parse(_ stream: Stream) {
        var keepAlive = false
        repeat {
            let parser = Parser(stream: stream)
            let serializer = Serializer(stream: stream)
            do {
                //let _ = try stream.receive(upTo: 2048)
                let request = try parser.parse()
                keepAlive = request.keepAlive
                let response = try responder.respond(to: request)
                try serializer.serialize(response)
                //try stream.send("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello".data)
            } catch {
                Log.error("HTTP error: \(error)")
                break //break to close stream on all errors
            }
        } while keepAlive && !stream.closed

        do {
            try stream.close()
        } catch {
            Log.error("Could not close stream: \(error)")
        }
    }

}

extension Request {
    var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        // TODO: Decide on if 'contains' is better, test linux version
        return !(value.trim() == "close")
    }
}
