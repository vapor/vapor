import Foundation
import Service

/// A basic Cache implementation that stores
/// data in local memory.
/// - Note: This class is usually only used for testing,
///         as large applications must multiple replicas
///         that do not share memory.
public final class MemoryCache: Cache {
    // Private storage
    private var _storage: [String: (Date?, CacheData)]

    /// Used to synchronize access to the session data.
    private var lock = NSLock()

    /// Creates a new MemoryCache.
    public init() {
        _storage = [:]
    }

    /// See Cache.get()
    public func get(_ key: String) throws -> CacheData {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let (expiration, value) = _storage[key] else {
            return .null
        }

        if let expiration = expiration {
            return expiration.timeIntervalSinceNow > 0 ? value : .null
        }

        return value
    }

    /// See Cache.set()
    public func set(_ key: String, to data: CacheData, expiration: Date?) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        _storage[key] = (expiration, data)
    }

    /// See Cache.delete()
    public func delete(_ key: String) throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        _storage.removeValue(forKey: key)
    }
}

// MARK: Service

extension MemoryCache: ServiceType {
    /// See ServiceType.serviceName
    public static var serviceName: String {
        return "memory"
    }

    /// See ServiceType.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Cache.self]
    }

    /// See ServiceType.makeService()
    public static func makeService(for container: Container) throws -> Self? {
        return .init()
    }
}
