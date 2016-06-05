import Socks
import SocksCore

extension Socks.TCPClient: Stream {
    public enum Error: ErrorProtocol {
        case unsupported
    }

    public var closed: Bool {
        return socket.isClosed
    }

    public func send(_ data: Data, timingOut deadline: Double) throws {
        try send(bytes: data.bytes)
    }

    public func flush(timingOut deadline: Double) throws {
        throw Error.unsupported
    }

    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        let bytes = try receive(maxBytes: byteCount)
        return Data(bytes)
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
