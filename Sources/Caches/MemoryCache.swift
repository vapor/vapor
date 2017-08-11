import Foundation
import Mapper

public final class MemoryCache: Cache {
    private var _storage: [String: (Date?, CacheData)]

    public init() {
        _storage = [:]
    }

    public func get(_ key: String) throws -> CacheData {
        guard let (expiration, value) = _storage[key] else {
            return .null
        }

        if let expiration = expiration {
            return expiration.timeIntervalSinceNow > 0 ? value : .null
        }

        return value
    }

    public func set(_ key: String, to data: CacheData, expiration: Date?) throws {
        _storage[key] = (expiration, data)
    }

    public func delete(_ key: String) throws {
        _storage.removeValue(forKey: key)
    }
}
