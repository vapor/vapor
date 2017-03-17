import Crypto
import Cache
import Node

public final class CacheSessions: SessionsProtocol {
    public let cache: CacheProtocol
    public init(_ cache: CacheProtocol) {
        self.cache = cache
    }

    public func get(identifier: String) throws -> Session? {
        if let data = try cache.get(identifier) {
            return Session(identifier: identifier, data: data)
        } else {
            return nil
        }
    }

    public func set(_ session: Session) throws {
        try cache.set(session.identifier, session.data)
    }
    
    public func destroy(identifier: String) throws{
        try cache.delete(identifier)
        
    }

    public func makeIdentifier() throws -> String {
        return try Crypto.Random.bytes(count: 16).base64Encoded.makeString()
    }
}
