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
    public let stream: TCPInternetSocket

    public required init(host: String, port: Int) throws {
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
    public required init(host: String, port: Int) throws {
        try super.init(host: host, port: port)

        try stream.bind()
        try stream.listen(queueLimit: 4096)
    }

    public func accept() throws -> Stream {
        return try stream.accept()
    }
}
