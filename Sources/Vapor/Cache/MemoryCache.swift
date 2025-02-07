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
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.application.storage.get(MemoryCacheKey.self) {
            return existing
        } else {
            let new = MemoryCacheStorage()
            self.application.storage.set(MemoryCacheKey.self, to: new)
            return new
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

private struct MemoryCacheKey: LockKey, StorageKey {
    typealias Value = MemoryCacheStorage
}

private actor MemoryCacheStorage: Sendable {
    struct CacheEntryBox<T> {
        var expiresAt: Date?
        var value: T
        
        init(_ value: T) {
            self.expiresAt = nil
            self.value = value
        }
    }
    
    private var storage: [String: Any]
    private var lock: NIOLock
    
    init() {
        self.storage = [:]
        self.lock = .init()
    }
    
    func get<T>(_ key: String) -> T?
        where T: Decodable
    {
        self.lock.lock()
        defer { self.lock.unlock() }
        
        guard let box = self.storage[key] as? CacheEntryBox<T> else { return nil }
        if let expiresAt = box.expiresAt, expiresAt < Date() {
            self.storage.removeValue(forKey: key)
            return nil
        }
        
        return box.value
    }
    
    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?)
        where T: Encodable
    {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let value = value {
            var box = CacheEntryBox(value)
            if let expirationTime = expirationTime {
                box.expiresAt = Date().addingTimeInterval(TimeInterval(expirationTime.seconds))
            }
            self.storage[key] = box
        } else {
            self.storage.removeValue(forKey: key)
        }
    }
}

private struct MemoryCache: Cache {
    let storage: MemoryCacheStorage
    let eventLoop: EventLoop
    
    init(storage: MemoryCacheStorage, on eventLoop: EventLoop) {
        self.storage = storage
        self.eventLoop = eventLoop
    }
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T?
        where T: Decodable & Sendable
    {
        await self.storage.get(key)
    }
    
    func set<T>(_ key: String, to value: T?) async throws -> Void
        where T: Encodable & Sendable
    {
        try await self.set(key, to: value, expiresIn: nil)
    }
    
    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) async throws -> Void
        where T: Encodable & Sendable
    {
        await self.storage.set(key, to: value, expiresIn: expirationTime)
    }
    
    func `for`(_ request: Request) -> MemoryCache {
        .init(storage: self.storage, on: request.eventLoop)
    }
}
