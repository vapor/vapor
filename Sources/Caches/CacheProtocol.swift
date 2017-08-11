import Foundation

public protocol Cache {
    func get(_ key: String) throws -> CacheData
    func set(_ key: String, to data: CacheData, expiration: Date?) throws
    func delete(_ key: String) throws
    func makeDefaultExpiration() -> Date?
}

extension Cache {
    public func makeDefaultExpiration() -> Date? {
        return nil
    }
}

extension Cache {
    public func set(_ key: String, to data: CacheDataRepresentable) throws {
        return try set(key, to: data.makeCacheData(), expiration: makeDefaultExpiration())
    }
    
    public func set(_ key: String, to data: CacheDataRepresentable, expireAfter: TimeInterval) throws {
        return try set(key, to: data.makeCacheData(), expiration: Date(timeIntervalSinceNow: expireAfter))
    }

    public func get<T: CacheDataInitializable>(_ key: String) throws -> T {
        return try T(cacheData: get(key))
    }
}
