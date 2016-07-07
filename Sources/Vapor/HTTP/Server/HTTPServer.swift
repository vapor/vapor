//#if os(Linux)
//    import Glibc
//#else
//    import Darwin
//#endif
//
//import Strand
//import Socks
//import SocksCore
//
//public final class HTTPServer<
//    ServerStreamType: ServerStream,
//    Parser: TransferParser,
//    Serializer: TransferSerializer
//    where
//        Parser.MessageType == HTTPRequest,
//        Serializer.MessageType == HTTPResponse
//>: Server {
//
//    let server: ServerStreamType
//
//    public let host: String
//    public let port: Int
//    public let securityLayer: SecurityLayer
//
//    public init(host: String = "0.0.0.0", port: Int = 8080, securityLayer: SecurityLayer = .none) throws {
//        self.host = host
//        self.port = port
//        self.securityLayer = securityLayer
//
//        do {
//            server = try ServerStreamType(host: host, port: port, securityLayer: securityLayer)
//        } catch {
//            throw ServerError.bind(host: host, port:port, error)
//        }
//    }
//
//    public func start(responder: Responder, errors: ServerErrorHandler) throws {
//        // no throwing inside of the loop
//        while true {
//            let stream: Stream
//
//            do {
//                stream = try server.accept()
//            } catch {
//                errors(.accept(error))
//                continue
//            }
//
//            do {
//                _ = try Strand {
//                    do {
//                        try self.respond(stream: stream, responder: responder)
//                    } catch {
//                        errors(.dispatch(error))
//                    }
//                }
//            } catch {
//                errors(.dispatch(error))
//            }
//        }
//    }
//
//    private func respond(stream: Stream, responder: Responder) throws {
//        let stream = StreamBuffer(stream)
//        try stream.setTimeout(30)
//
//        let parser = Parser(stream: stream)
//        let serializer = Serializer(stream: stream)
//
//        var keepAlive = false
//        repeat {
//            let request = try parser.parse()
//            keepAlive = request.keepAlive
//            let response = try responder.respond(to: request)
//            try serializer.serialize(response)
//            try response.onComplete?(stream)
//        } while keepAlive && !stream.closed
//
//        try stream.close()
//    }
//}
