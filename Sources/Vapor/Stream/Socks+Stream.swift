import Socks
import SocksCore

extension timeval {
    init(seconds: Double) {
        let time = (seconds >= 0) ? Int(seconds) : 0
        self.init(seconds: time)
    }
}

extension TCPInternetSocket: Stream {
    public func setTimeout(_ timeout: Double) throws {
        sendingTimeout = timeval(seconds: timeout)
    }

    public func send(_ bytes: Bytes) throws {
        print(bytes.string, terminator: "")
        try send(data: bytes)
    }

    public func flush() throws {
        // flushing is unnecessary, send immediately sends
    }

    public func receive(max: Int) throws -> Bytes {
        return try recv(maxBytes: max)
    }
}

public class TCPProgramStream: ProgramStream {
    let host: String
    let port: Int
    let securityLayer: SecurityLayer
    public let stream: TCPInternetSocket

    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer

        let address = InternetAddress(hostname: host, port: Port(port))
        stream = try TCPInternetSocket(address: address)
    }
}

public final class TCPClientStream: TCPProgramStream, ClientStream  {
    public func connect() throws -> Stream {
        if securityLayer == .tls {
            #if !os(Linux)
                Log.warning("Using Foundation stream for now. This is not supported on linux ... visit https://github.com/qutheory/vapor-ssl for install instructions")
                let foundation = try FoundationStream(host: host, port: port, securityLayer: securityLayer)
                return try foundation.connect()
            #else
                Log.warning("TCP CLIENT DOES NOT SUPPORT SSL CONNECTIONS ... visit https://github.com/qutheory/vapor-ssl for install")
            #endif

        }
        try stream.connect()
        return stream
    }
}

public final class TCPServerStream: TCPProgramStream, ServerStream {
    public required init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        try super.init(host: host, port: port, securityLayer: securityLayer)

        try stream.bind()
        try stream.listen(queueLimit: 4096)
    }

    public func accept() throws -> Stream {
        return try stream.accept()
    }
}
