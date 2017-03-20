import Node
import Foundation

public final class MemoryCache: CacheProtocol {
    private var _storage: [String: (Date?, Node)]

    public init() {
        _storage = [:]
    }

    public func get(_ key: String) throws -> Node? {
        guard let (expiration, value) = _storage[key] else {
            return nil
        }

        if let expiration = expiration {
            return expiration.timeIntervalSinceNow > 0 ? value : nil
        }

        return value
    }

    public func set(_ key: String, _ value: Node, expiration: Date?) throws {
        _storage[key] = (expiration, value)
    }

    public func delete(_ key: String) throws {
        _storage.removeValue(forKey: key)
    }
}
