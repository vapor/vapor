import Socks
import SocksCore

extension timeval {
    init(seconds: Double) {
        let time = (seconds >= 0) ? Int(seconds) : 0
        self.init(seconds: time)
    }
}

extension Socks.TCPClient: Stream {
    public var closed: Bool {
        return socket.closed
    }

    public var timeout: Double {
        get {
            // TODO: Implement a way to view the timeout
            return 0
        }
        set {
            socket.sendingTimeout = timeval(seconds: newValue)
        }
    }

    public func send(_ bytes: Bytes) throws {
        try send(bytes: bytes)
    }

    public func flush() throws {
        //
    }

    public func receive(max: Int) throws -> Bytes {
        return try receive(maxBytes: max)
    }
}

extension SynchronousTCPServer: StreamDriver {
    public static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws {
        let port = UInt16(port)
        let address = InternetAddress(hostname: host, port: port)
        let server = try SynchronousTCPServer(address: address)
        try server.startWithHandler(handler: handler)
    }
}
