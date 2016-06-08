#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Strand
import SocksCore

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
        try server.start(handler: handle)
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
                let request = try parser.parse()
                keepAlive = request.keepAlive
                let response = try responder.respond(to: request)
                try serializer.serialize(response)

                guard response.isUpgradeResponse else { continue }
                try response.onUpgrade?(stream)
            } catch let e as SocksCore.Error where e.isClosedByPeer {
                break // jumpto close
            } catch let e as HTTPParser.Error where e == .streamEmpty {
                break // jumpto close
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

extension SocksCore.Error {
    var isClosedByPeer: Bool {
        guard case .ReadFailed = type else { return false }
        let message = String(validatingUTF8: strerror(errno))
        return message == "Connection reset by peer"
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

extension Response {
    var isUpgradeResponse: Bool {
        return headers.connection == "Upgrade"
    }
}
