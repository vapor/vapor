//import SocksCore
//
//extension TCPInternetSocket: Stream {
//    public func setTimeout(_ timeout: Double) throws {
//        sendingTimeout = timeval(seconds: timeout)
//    }
//
//    public func send(_ bytes: Bytes) throws {
//        //print(bytes.string)
//        do {
//            try send(data: bytes)
//        } catch {
//            throw StreamError.send("There was a problem while sending data.", error)
//        }
//    }
//
//    public func flush() throws {
//        // flushing is unnecessary, send immediately sends
//    }
//
//    public func receive(max: Int) throws -> Bytes {
//        do {
//            let bytes = try recv(maxBytes: max)
//            //print(bytes.string)
//            return bytes
//        } catch {
//            throw StreamError.receive("There was a problem while receiving data.", error)
//        }
//    }
//}
//
//public class TCPProgramStream: ProgramStream {
//    public let host: String
//    public let port: Int
//    public let securityLayer: SecurityLayer
//    public let stream: TCPInternetSocket
//
//    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
//        self.host = host
//        self.port = port
//        self.securityLayer = securityLayer
//
//        let address = InternetAddress(hostname: host, port: Port(port))
//        stream = try TCPInternetSocket(address: address)
//    }
//}
//
//public final class TCPClientStream: TCPProgramStream, ClientStream  {
//    public func connect() throws -> Stream {
//        if securityLayer == .tls {
//            #if !os(Linux)
//                let foundation = try FoundationStream(host: host, port: port, securityLayer: securityLayer)
//                return try foundation.connect()
//            #else
//                throw ProgramStreamError.unsupportedSecurityLayer
//            #endif
//
//        }
//        try stream.connect()
//        return stream
//    }
//}
//
//public final class TCPServerStream: TCPProgramStream, ServerStream {
//    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
//        try super.init(host: host, port: port, securityLayer: securityLayer)
//
//        try stream.bind()
//        try stream.listen(queueLimit: 4096)
//    }
//
//    public func accept() throws -> Stream {
//        return try stream.accept()
//    }
//}
