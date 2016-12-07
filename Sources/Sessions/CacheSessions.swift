import Random
import Cache
import Node

public final class CacheSessions: SessionsProtocol {
    public let cache: CacheProtocol
    public init(cache: CacheProtocol) {
        self.cache = cache
    }

    public func get(for identifier: String) throws -> Session? {
        let data = try cache.get(identifier)
        return Session(identifier: identifier, data: data ?? .null)
    }

    public func set(_ session: Session?, for identifier: String) throws {
        if let session = session {
            try cache.set(identifier, session.data)
        } else {
            try cache.delete(identifier)
        }
    }

    public func makeIdentifier() -> String {
        return CryptoRandom.bytes(16).base64String
    }
}
