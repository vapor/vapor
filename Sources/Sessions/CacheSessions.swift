import Random
import Cache
import Node

public final class CacheSessions: SessionsProtocol {
    public let cache: CacheProtocol
    public init(cache: CacheProtocol) {
        self.cache = cache
    }

    public func get(for identifier: String) throws -> Node? {
        return try cache.get(identifier)
    }

    public func set(_ value: Node?, for identifier: String) throws {
        if let value = value {
            try cache.set(identifier, value)
        } else {
            try cache.delete(identifier)
        }
    }

    public func makeIdentifier() -> String {
        return CryptoRandom.bytes(16).base64String
    }
}
