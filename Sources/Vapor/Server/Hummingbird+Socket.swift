import Foundation

extension Hummingbird.Socket: Socket {
    public var id: String {
        return "\(socketDescriptor)"
    }
    
    public func read(bufferLength: Int) throws -> [Byte] {
        return try recv(bufferLength)
    }
    
    public func write(bytes: [Byte]) throws {
        try send(bytes)
    }
    
    public func accept(connectionHandler: Socket -> Void) throws {
        try accept(Int(SOMAXCONN), connectionHandler: connectionHandler)
    }
}
