import Hummingbird

extension Hummingbird.Socket: Stream {

    enum Error: ErrorProtocol {
        case Unsupported
    }

    public var closed: Bool {
        return false
    }

    public func close() -> Bool {
        return false
    }

    public func receive(maxBytes: Int) throws -> Data {
        let bytes: [Byte] = try self.receive(maximumBytes: maxBytes) ?? []
        return Data(bytes)
    }

    public func send(data: Data) throws {
        try self.send(data.bytes)
    }

    public func flush() throws {
        throw Error.Unsupported
    }

}
