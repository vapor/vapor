import Random
import Cache
import Node

public final class CacheSessions: SessionsProtocol {
    public let cache: CacheProtocol
    public init(cache: CacheProtocol) {
        self.cache = cache
    }

    public func get(for identifier: String) throws -> Node? {
        do {
           return try cache.get(identifier)
        } catch {
            print("[CacheSessions] Error getting data: \(error)")
            return nil
        }
    }

    public func set(_ value: Node?, for identifier: String) throws {
        do {
            if let value = value {
                try cache.set(identifier, value)
            } else {
                try cache.delete(identifier)
            }
        } catch {
            print("[CacheSessions] Error setting data: \(error)")
        }
    }

    public func makeIdentifier() -> String {
        return CryptoRandom.bytes(16).base64Encoded.string
    }
}
