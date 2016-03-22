import Hummingbird

extension Hummingbird.Socket: Socket {
    public func read(bufferLength: Int) throws -> [Byte] {
        return try receive(maximumBytes: bufferLength)
    }

    public func write(bytes: [Byte]) throws {
        try send(bytes)
    }

    public static func makeSocket() throws -> Hummingbird.Socket {
        return try makeStreamSocket()
    }
}
