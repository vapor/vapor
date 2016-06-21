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
        try send(data: bytes)
    }

    public func flush() throws {
        // flushing is unnecessary, send immediately sends
    }

    public func receive(max: Int) throws -> Bytes {
        return try recv(maxBytes: max)
    }
}

public class TCPAddressStream: AddressStream {
    public let scheme: String
    public let host: String
    public let port: Int
    public let stream: TCPInternetSocket

    public required init(scheme: String, host: String, port: Int) throws {
        self.scheme = scheme
        self.host = host
        self.port = port

        let address = InternetAddress(hostname: host, port: Port(port))
        stream = try TCPInternetSocket(address: address)
    }
}

public final class TCPClientStream: TCPAddressStream, ClientStream  {
    public func connect() throws -> Stream {
        try stream.connect()
        return stream
    }
}

public final class TCPServerStream: TCPAddressStream, ServerStream {
    public required init(scheme: String, host: String, port: Int) throws {
        try super.init(scheme: scheme, host: host, port: port)

        try stream.bind()
        try stream.listen(queueLimit: 4096)
    }

    public func accept() throws -> Stream {
        let wss = scheme == "wss"
        let https = scheme == "https"
        let secure = wss || https
        if secure {
            Log.warning("TCPServer does not support secure connection")
            throw ClientsError.unsupportedScheme
        }
        return try stream.accept()
    }
}
