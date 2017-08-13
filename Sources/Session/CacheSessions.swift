import Crypto
import Cache
import Foundation
import Service

/// Uses a Cache to store and fetch Sessions.
public final class CacheSessions: Sessions {
    /// The cache sessions will be serialized to/from.
    public let cache: Cache

    /// Creates a new CacheSessions.
    public init(cache: Cache) {
        self.cache = cache
    }

    /// See Sessions.get()
    public func get(identifier: String) throws -> Session? {
        let cacheData = try cache.get(identifier)
        guard cacheData != .null else {
            return nil
        }

        /// let sessionData = try cacheData.converted(to: SessionData.self)
        // FIXME
        let sessionData = SessionData.null
        return Session(identifier: identifier, data: sessionData)
    }

    /// See Sessions.set()
    public func set(_ session: Session) throws {
        // FIXME
        // let cacheData = try session.data.converted(to: CacheData.self)
        let cacheData = CacheData.null
        try cache.set(session.identifier, to: cacheData, expiration: nil)
    }

    /// See Sessions.destroy()
    public func destroy(identifier: String) throws{
        try cache.delete(identifier)
    }
}

// MARK: Service

extension CacheSessions: ServiceType {
    /// See Service.serviceName
    public static var serviceName: String {
        return "cache"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Sessions.self]
    }

    /// See Service.makeService()
    public static func makeService(for container: Container) throws -> CacheSessions? {
        return try CacheSessions(
            cache: container.make()
        )
    }
}

