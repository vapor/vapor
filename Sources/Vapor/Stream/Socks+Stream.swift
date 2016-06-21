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
    let scheme: String
    let host: String
    let port: Int
    public let stream: TCPInternetSocket

    public required init(scheme: String, host: String, port: Int) throws {
        self.scheme = scheme
        self.host = host
        self.port = port
        let address = InternetAddress(hostname: host, port: Port(port))
        stream = try TCPInternetSocket(address: address)
    }
}

public final class TCPClientStream: TCPProgramStream, ClientStream  {
    public func connect() throws -> Stream {
        if scheme == "wss" || scheme == "https" {
            #if !os(Linux)
                Log.warning("Using Foundation stream for now. This is not supported on linux ... visit https://github.com/qutheory/vapor-ssl for install instructions")
                let foundation = try FoundationStream(scheme: scheme, host: host, port: port)
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
    public required init(scheme: String, host: String, port: Int) throws {
        try super.init(scheme: scheme, host: host, port: port)

        try stream.bind()
        try stream.listen(queueLimit: 4096)
    }

    public func accept() throws -> Stream {
        return try stream.accept()
    }
}
