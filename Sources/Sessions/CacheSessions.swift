import Random
import Cache
import Node
import Foundation

public final class CacheSessions: SessionsProtocol {
    public let cache: CacheProtocol
    private let defaultExpiration: TimeInterval?
    
    public init(cache: CacheProtocol, defaultExpiration: TimeInterval? = nil) {
        self.cache = cache
        self.defaultExpiration = defaultExpiration
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
                let expiration = defaultExpiration.map { Date(timeIntervalSinceNow: $0) }
                try cache.set(identifier, value, expiration: expiration)
            } else {
                try cache.delete(identifier)
            }
        } catch {
            print("[CacheSessions] Error setting data: \(error)")
        }
    }

    public func makeIdentifier() -> String {
        // FIXME: version 2.0 will throw
        return try! CryptoRandom.bytes(count: 16).base64Encoded.string
    }
}
