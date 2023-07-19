import Foundation
import NIOCore
import NIOConcurrencyHelpers

extension Application.Caches {
    /// In-memory cache. Thread safe.
    /// Not shared between multiple instances of your application.
    public var memory: Cache {
        MemoryCache(storage: self.memoryStorage, on: self.application.eventLoopGroup.next())
    }

    private var memoryStorage: MemoryCacheStorage {
        let lock = self.application.locks.lock(for: MemoryCacheKey.self)
        return lock.withLock {
            if let existing = self.application.storage.get(MemoryCacheKey.self) {
                return existing
            } else {
                let new = MemoryCacheStorage()
                self.application.storage.set(MemoryCacheKey.self, to: new)
                return new
            }
        }
    }
}

extension Application.Caches.Provider {
    /// In-memory cache. Thread safe.
    /// Not shared between multiple instances of your application.
    public static var memory: Self {
        .init {
            $0.caches.use { $0.caches.memory }
        }
    }
}

private struct MemoryCacheKey: Sendable, LockKey, StorageKey {
    typealias Value = MemoryCacheStorage
}

private final class MemoryCacheStorage: Sendable {
    struct CacheEntryBox<T: Sendable>: Sendable {
        var expiresAt: Date?
        var value: T
        
        init(_ value: T) {
            self.expiresAt = nil
            self.value = value
        }
    }
    
    private let storage: NIOLockedValueBox<[String: Sendable]>
    
    init() {
        self.storage = .init([:])
    }
    
    func get<T: Sendable>(_ key: String) -> T?
        where T: Decodable
    {
        let entry = self.storage.withLockedValue { $0[key] as? CacheEntryBox<T> }
        guard let box = entry else { return nil }
        if let expiresAt = box.expiresAt, expiresAt < Date() {
            // This is a discardable result under the hood, we get a compiler warning
            // because it's wrapped in NIOLockedValueBox without the _ = ...
            _  = self.storage.withLockedValue { $0.removeValue(forKey: key) }
            return nil
        }
        
        return box.value
    }
    
    func set<T: Sendable>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?)
        where T: Encodable
    {
        if let value = value {
            var box = CacheEntryBox(value)
            if let expirationTime = expirationTime {
                box.expiresAt = Date().addingTimeInterval(TimeInterval(expirationTime.seconds))
            }
            self.storage.withLockedValue { $0[key] = box }
        } else {
            // This is a discardable result under the hood, we get a compiler warning
            // because it's wrapped in NIOLockedValueBox without the _ = ...
            _ = self.storage.withLockedValue { $0.removeValue(forKey: key) }
        }
    }
}

private struct MemoryCache: Sendable, Cache {
    let storage: MemoryCacheStorage
    let eventLoop: EventLoop
    
    init(storage: MemoryCacheStorage, on eventLoop: EventLoop) {
        self.storage = storage
        self.eventLoop = eventLoop
    }
    
    func get<T: Sendable>(_ key: String, as type: T.Type) -> EventLoopFuture<T?>
        where T: Decodable
    {
        self.eventLoop.makeSucceededFuture(self.storage.get(key))
    }
    
    func set<T: Sendable>(_ key: String, to value: T?) -> EventLoopFuture<Void>
        where T: Encodable
    {
        self.set(key, to: value, expiresIn: nil)
    }
    
    func set<T: Sendable>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) -> EventLoopFuture<Void>
        where T: Encodable
    {
        self.storage.set(key, to: value, expiresIn: expirationTime)
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func `for`(_ request: Request) -> MemoryCache {
        .init(storage: self.storage, on: request.eventLoop)
    }
}
