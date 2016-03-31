import Hummingbird
import C7

extension Hummingbird.Socket: Socket {
    public func read(bufferLength: Int) throws -> [C7.Byte] {
        return try receive(maximumBytes: bufferLength)
    }
    
    public func write(bytes: [C7.Byte]) throws {
        try send(bytes)
    }
    
    public static func makeSocket() throws -> Hummingbird.Socket {
        return try makeStreamSocket()
    }
}
