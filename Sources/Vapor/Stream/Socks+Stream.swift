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
            socket.receivingTimeout = timeval(seconds: newValue)
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
    public static func make(host: String, port: Int) throws -> Self {
        let port = UInt16(port)
        let address = InternetAddress(hostname: host, port: port)

        return try .init(address: address)
    }

    public func start(handler: (Stream) throws -> ()) throws {
        try self.startWithHandler(handler: handler)
    }
}
