#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Strand
import SocksCore

enum ServerError: ErrorProtocol {
    case bindFailed
}

public protocol HTTPResponder {
    func respond(to request: HTTP.Request) throws -> HTTP.Response
}

public protocol HTTPServerProtocol {
    init(host: String, port: Int, responder: HTTP.Responder) throws
    @noreturn func start() throws
}

extension HTTP {
    // Can't nest protocol, but can nest typealias
    public typealias Responder = HTTPResponder
    public typealias ServerProtocol = HTTPServerProtocol
}

final class HTTPServer<StreamDriverType: StreamDriver, Parser: HTTP.ParserProtocol, Serializer: HTTP.SerializerProtocol>: HTTPServerProtocol {
    let host: String
    let port: Int

    let responder: HTTP.Responder

    required init(host: String = "0.0.0.0",
                  port: Int = 8080,
                  responder: HTTP.Responder) throws {
        self.host = host
        self.port = port
        self.responder = responder
    }

    @noreturn func start() throws {
        do {
            try StreamDriverType.listen(host: host, port: port, handler: handle)
        } catch let e as SocksCore.Error where e.isBindFailed {
            throw ServerError.bindFailed
        }
    }

    private func handle(_ stream: Stream) {
        do {
            _ = try Strand {
                self.loop(with: stream)
            }
        } catch {
            Log.error("Could not create thread: \(error)")
        }
    }

    private func loop(with stream: Stream) {
        let stream = StreamBuffer(stream)
        stream.timeout = 30

        let parser = Parser(stream: stream)
        let serializer = Serializer(stream: stream)

        var keepAlive = false
        repeat {
            do {
                let request = try parser.parse(HTTP.Request.self)
                keepAlive = request.keepAlive
                let response = try responder.respond(to: request)
                try serializer.serialize(response)
                try response.onComplete?(stream)
            } catch let e as SocksCore.Error where e.isClosedByPeer {
                // stream was closed by peer, abort
                break
            } catch let e as SocksCore.Error where e.isBrokenPipe {
                // broken pipe, abort
                break
            } catch HTTP.Parser.Error.streamEmpty {
                // the stream we got was empty, abort
                break
            } catch {
                // unknown error, abort
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

extension SocksCore.Error {
    var isClosedByPeer: Bool {
        guard case .readFailed = type else { return false }
        let message = String(validatingUTF8: strerror(errno))
        return message == "Connection reset by peer"
    }
    var isBrokenPipe: Bool {
        return self.number == 32
    }
    var isBindFailed: Bool {
        return self.number == 48
    }
}
