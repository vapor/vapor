import Socks

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
