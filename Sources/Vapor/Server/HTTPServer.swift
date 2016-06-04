#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Socks
import SocksCore
import Strand

// MARK: Byte => Character
extension Character {
    init(_ byte: Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}

final class HTTPServer: ServerDriver {
    var stream: SynchronousTCPServer
    var responder: Responder
    var parser: HTTPParser.Type
    var serializer: HTTPSerializer

    required init(host: String, port: Int, responder: Responder) throws {
        let port = Port.portNumber(UInt16(port))
        let address = InternetAddress(hostname: host, port: port)

        stream = try SynchronousTCPServer(address: address)
        parser = HTTPParser.self
        serializer = HTTPSerializer()
        self.responder = responder
    }

    func start() throws {
        do {
            try stream.startWithHandler(handler: handle)
        } catch {
            Log.error("Failed to accept: \(stream) error: \(error)")
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
            let parser = HTTPParser(stream: stream)
            do {
                let request = try parser.parse()
                keepAlive = request.keepAlive
                let response = try responder.respond(to: request)
                let data = serializer.serialize(response, keepAlive: keepAlive)
                try stream.send(data)
            } catch let e as SocksCore.Error where e.isClosedByPeer {
                break // jumpto close
            } catch let e as HTTPParser.Error where e == .bufferEmpty {
                break // jumpto close
            } catch {
                Log.error("HTTP error: \(error)")
                break
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

extension SocksCore.Error {
    var isClosedByPeer: Bool {
        guard case .ReadFailed = type else { return false }
        let message = String(validatingUTF8: strerror(errno))
        return message == "Connection reset by peer"
    }
}
