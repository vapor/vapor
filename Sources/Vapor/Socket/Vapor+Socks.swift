import Socks
import SocksCore

extension timeval {
    init(seconds: Double) {
        self = timeval(tv_sec: Int(seconds), tv_usec: 0)
    }
}

extension Socks.TCPClient: Stream {
    public var closed: Bool {
        return socket.closed
    }

    public func send(_ data: Data, timingOut deadline: Double) throws {
        // TODO: Verify setting sending timeout is not slow
        socket.sendingTimeout = timeval(seconds: deadline)
        try send(bytes: data.bytes)
    }

    public func flush(timingOut deadline: Double) throws {
        socket.sendingTimeout = timeval(seconds: deadline)
        // no need to flush, there is no buffer
    }

    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        // TODO: Verify setting receiving timeout is not slow
        socket.receivingTimeout = timeval(seconds: deadline)
        let bytes = try receive(maxBytes: byteCount)
        return Data(bytes)
    }
}

extension SynchronousTCPServer: StreamDriver {
    public static func make(host: String, port: Int) throws -> Self {
        let port = UInt16(port)
        let address = InternetAddress(hostname: host, port: port)

        return try .init(address: address)
    }

    public func start(handler: (Stream) throws -> ()) throws {
        try self.startWithHandler(handler: handler)
    }
}
