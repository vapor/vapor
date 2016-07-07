//public enum HTTPClientError: ErrorProtocol {
//    case invalidRequestHost
//    case invalidRequestScheme
//    case invalidRequestPort
//    case unableToConnect
//    case userInfoNotAllowedOnHTTP
//}
//
//public final class HTTPClient<ClientStreamType: ClientStream>: Client {
//    public let host: String
//    public let port: Int
//    public let securityLayer: SecurityLayer
//
//    public let stream: Stream
//
//    public init(host: String, port: Int, securityLayer: SecurityLayer) throws {
//        self.host = host
//        self.port = port
//        self.securityLayer = securityLayer
//
//        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
//        let stream = try client.connect()
//        self.stream = stream
//    }
//
//    public func respond(to request: Request) throws -> Response {
//        try assertValid(request)
//        guard !stream.closed else { throw HTTPClientError.unableToConnect }
//        let buffer = StreamBuffer(stream)
//
//        /*
//             A client MUST send a Host header field in all HTTP/1.1 request
//             messages.  If the target URI includes an authority component, then a
//             client MUST send a field-value for Host that is identical to that
//             authority component, excluding any userinfo subcomponent and its "@"
//             delimiter (Section 2.7.1).  If the authority component is missing or
//             undefined for the target URI, then a client MUST send a Host header
//             field with an empty field-value.
//        */
//        request.headers["Host"] = host
//
//        let serializer = HTTPSerializer<Request>(stream: buffer)
//        try serializer.serialize(request)
//
//        let parser = HTTPParser<Response>(stream: buffer)
//        let response = try parser.parse()
//
//        try buffer.flush()
//
//        return response
//    }
//
//    private func assertValid(_ request: Request) throws {
//        if !request.uri.host.isNilOrEmpty {
//            guard request.uri.host == host else { throw HTTPClientError.invalidRequestHost }
//        }
//
//        if !request.uri.scheme.isNilOrEmpty {
//            guard request.uri.scheme?.securityLayer == securityLayer else { throw HTTPClientError.invalidRequestScheme }
//        }
//
//        if let requestPort = request.uri.port {
//            guard requestPort == port else { throw HTTPClientError.invalidRequestPort }
//        }
//
//        guard request.uri.userInfo == nil else {
//            /*
//                 Userinfo (i.e., username and password) are now disallowed in HTTP and
//                 HTTPS URIs, because of security issues related to their transmission
//                 on the wire.  (Section 2.7.1)
//            */
//            throw HTTPClientError.userInfoNotAllowedOnHTTP
//        }
//    }
//}
