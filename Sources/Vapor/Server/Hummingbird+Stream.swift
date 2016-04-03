import Hummingbird

extension Hummingbird.Socket {
    func makeStream() -> HummingbirdStream {
        return HummingbirdStream(socket: self)
    }
}

public class HummingbirdStream: Stream {

    weak var socket: Hummingbird.Socket?
    init(socket: Hummingbird.Socket) {
        self.socket = socket
    }


    enum Error: ErrorProtocol {
        case Unsupported
    }

    public var closed: Bool {
        return false
    }

    public func close() -> Bool {
        return false
    }

    public func receive() throws -> Data {
        let bytes: [Byte] = try socket?.receive() ?? []
        return Data(bytes)
    }

    public func send(data: Data) throws {
        try socket?.send(data.bytes)
    }

    public func flush() throws {
        throw Error.Unsupported
    }

}

