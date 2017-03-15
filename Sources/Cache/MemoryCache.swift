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

    public func set(_ key: String, _ value: Node, expiration: Double?) throws {
        let expirationDate: Date?
        
        if let expiration = expiration {
            expirationDate = Date(timeIntervalSinceNow: expiration)
        } else {
            expirationDate = nil
        }
        
        _storage[key] = (expirationDate, value)
    }

    public func delete(_ key: String) throws {
        _storage.removeValue(forKey: key)
    }
}
