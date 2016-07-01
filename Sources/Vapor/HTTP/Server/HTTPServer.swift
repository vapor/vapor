#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Strand
import Socks
import SocksCore
import Foundation

public protocol Program {
    init(host: String, port: Int, securityLayer: SecurityLayer) throws
}

public protocol Server: Program {
    func start(responder: Responder, errors: ServerErrorHandler) throws
}

public typealias ServerErrorHandler = (ServerError) -> ()

public enum ServerError: ErrorProtocol {
    case bind(ErrorProtocol)
    case accept(ErrorProtocol)
    case respond(ErrorProtocol)
    case dispatch(ErrorProtocol)
    case unknown(ErrorProtocol)
}

public final class HTTPServer<
    ServerStreamType: ServerStream,
    Parser: TransferParser,
    Serializer: TransferSerializer
    where
        Parser.MessageType == HTTPRequest,
        Serializer.MessageType == HTTPResponse
>: Server {

    let server: ServerStreamType

    public init(host: String = "0.0.0.0", port: Int = 8080, securityLayer: SecurityLayer = .none) throws {
        do {
            server = try ServerStreamType(host: host, port: port)
        } catch {
            throw ServerError.bind(error)
        }
    }

    public func start(responder: Responder, errors: ServerErrorHandler) throws {

        // no throwing inside of the loop
        while true {
            let stream: Stream

            do {
                stream = try server.accept()
            } catch {
                errors(.accept(error))
                continue
            }

            do {
                _ = try Strand {
                    do {
                        try self.respond(stream: stream, responder: responder)
                    } catch {
                        errors(.dispatch(error))
                    }
                }
            } catch {
                errors(.dispatch(error))
            }
        }
    }

    private func respond(stream: Stream, responder: Responder) throws {
        let stream = StreamBuffer(stream)
        try stream.setTimeout(30)

        let parser = Parser(stream: stream)
        let serializer = Serializer(stream: stream)

        var keepAlive = false
        repeat {
            let request = try parser.parse()
            keepAlive = request.keepAlive
            let response = try responder.respond(to: request)
            try serializer.serialize(response)
            try response.onComplete?(stream)
        } while keepAlive && !stream.closed

        try stream.close()
    }
}
