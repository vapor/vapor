import Foundation
import Hummingbird

extension Hummingbird.Socket: Socket {
    public var id: String {
        return "\(hashValue)"
    }
    
    public func read(bufferLength: Int) throws -> [Byte] {
        return try receive(bufferLength)
    }
    
    public func write(bytes: [Byte]) throws {
        try send(bytes)
    }
    
    
    public func accept(maximumConsecutiveFailures: Int, connectionHandler: (Socket) -> Void) throws {
        try accept(maximumConsecutiveFailures) { (sock: Hummingbird.Socket) in // Keep type explicit to prevent infinite loop
            connectionHandler(sock)
        }
    }
    
    public static func makeSocket() throws -> Socket {
        return try streamSocket()
    }
}
