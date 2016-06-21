#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Strand
import Socks
import SocksCore

public protocol Responder {
    func respond(to request: Request) throws -> Response
}

public protocol Program {

}


public enum Servers {
    case plaintext(Server)
    case secure(Server)
    case both(plaintext: Server)
}

public protocol Server: Program {
    func start(scheme: String, host: String, port: Int, responder: Responder, errors: ServerErrorHandler) throws
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
    public init() { }

    public func start(
        scheme: String,
        host: String = "0.0.0.0",
        port: Int = 8080,
        responder: Responder,
        errors: ServerErrorHandler
    ) throws {
        let server: ServerStreamType
        do {
            server = try ServerStreamType(scheme: scheme, host: host, port: port)
        } catch {
            throw ServerError.bind(error)
        }

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
                        errors(.respond(error))
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
