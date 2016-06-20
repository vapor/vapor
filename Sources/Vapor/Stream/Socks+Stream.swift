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

extension TCPClient: ClientStream {
    public static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream {
        if usingSSL {
            #if !os(Linux)
                Log.warning("Using Foundation stream for now. This is not supported on linux ... // TODO: link to instructions")
                return try FoundationStream.makeConnection(host: host, port: port, usingSSL: usingSSL)
            #else
                Log.warning("TCP CLIENT DOES NOT SUPPORT SSL CONNECTIONS")
            #endif
        }
        let port = UInt16(port)
        let address = InternetAddress(hostname: host, port: port)
        return try TCPClient(address: address)
    }
}
