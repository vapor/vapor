import Foundation

/// Caches are used to store and retrieve simple
/// data using String keys. Caches are ofented
/// use to improve the performance of an application.
public protocol Cache {
    /// Returns the CacheData at the supplied key.
    /// Returns `CacheData.null` if no key exists.
    func get(_ key: String) throws -> CacheData

    /// Sets the supplied `CacheData` at the given key.
    /// If an expiration date is supplied, calling `.get`
    /// on the key will return `CacheData.null` after the date.
    func set(_ key: String, to data: CacheData, expiration: Date?) throws

    /// Removes a key from the cache, causing `.get()` to
    /// return `CacheData.null` for the key if it does not already.
    func delete(_ key: String) throws
}

extension Cache {
    /// Initializes a `CacheDataInitializable` type using the
    /// supplied data.
    public func get<T: CacheDecodable>(_ key: String) throws -> T {
        let data = try get(key)
        return try T(cacheData: data)
    }

//    /// Sets the key to a `CacheDataRepresentable` type.
//    /// - See `Cache.set()`
//    public func set<T: CacheDataRepresentable>(_ key: String, to data: T) throws {
//        return try set(key, to: data.makeCacheData(), expiration: nil)
//    }
//
//    /// Sets the key to a `CacheDataRepresentable` type that will
//    /// expire after the supplied time interval.
//    /// - See `Cache.set()`
//    public func set(_ key: String, to data: CacheDataRepresentable, expireAfter: TimeInterval) throws {
//        return try set(key, to: data.makeCacheData(), expiration: Date(timeIntervalSinceNow: expireAfter))
//    }
}
