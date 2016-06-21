#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Strand
import Socks
import SocksCore

public typealias Responder = HTTPResponder

public protocol HTTPResponder {
    func respond(to request: HTTPRequest) throws -> HTTPResponse
}

public protocol HTTPServerProtocol {
    init(host: String, port: Int, responder: HTTPResponder) throws
    func start() throws
}

public enum ServerError: ErrorProtocol {
    case bind(ErrorProtocol)
    case accept(ErrorProtocol)
    case respond(ErrorProtocol)
    case dispatch(ErrorProtocol)
    case unknown(ErrorProtocol)
}

public typealias ServerErrorHandler = (ServerError) -> ()

public protocol Server {
    static func start(host: String, port: Int, secure: Bool, responder: Responder, errors: ServerErrorHandler) throws
}

public protocol ServerStream {
    static func listen(host: String, port: Int, secure: Bool, handler: (Stream) throws -> ()) throws
}

public final class HTTPServer<
        ServerStreamType: ServerStream,
        Parser: TransferParser,
        Serializer: TransferSerializer
        where Parser.MessageType == HTTPRequest,
              Serializer.MessageType == HTTPResponse>: Server {

    public static func start(host: String, port: Int, secure: Bool, responder: Responder, errors: ServerErrorHandler) throws {
        do {
            try ServerStreamType.listen(host: host, port: port, secure: secure) { stream in
                do {
                    _ = try Strand {
                        self.loop(with: stream, notifying: responder)
                    }
                } catch {
                    Log.error("Could not create thread: \(error)")
                    errors(.dispatch(error))
                }
            }
        } catch let e as SocksCore.Error where e.isBindFailed {
            errors(.bind(e))
        }
    }

    private static func loop(with stream: Stream, notifying responder: Responder) {
        let stream = StreamBuffer(stream)
        stream.timeout = 30

        let parser = Parser(stream: stream)
        let serializer = Serializer(stream: stream)

        var keepAlive = false
        repeat {
            do {
                let request = try parser.parse()
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
            } catch HTTPParser.Error.streamEmpty {
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
