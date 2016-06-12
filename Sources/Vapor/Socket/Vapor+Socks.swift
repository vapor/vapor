import Socks
import SocksCore

extension Socks.TCPClient: Stream {
    public var closed: Bool {
        return socket.closed
    }

    public var timeout: Double {
        get {
            // todo
            return 0
        }
        set {
            // todo
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

    public func receive() throws -> Byte? {
        return try receive(maxBytes: 1).first
    }
}

extension SynchronousTCPServer: StreamDriver {
    public static func make(host: String, port: Int) throws -> Self {
        let port = Port.portNumber(UInt16(port))
        let address = InternetAddress(hostname: host, port: port)

        return try .init(address: address)
    }

    public func start(handler: (Stream) throws -> ()) throws {
        try self.startWithHandler(handler: handler)
    }
}
