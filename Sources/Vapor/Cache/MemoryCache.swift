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

private final class MemoryCacheStorage {
    private var storage: [String: Any]
    private var lock: Lock
    
    init() {
        self.storage = [:]
        self.lock = .init()
    }
    
    func get<T>(_ key: String) -> T?
        where T: Decodable
    {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage[key] as? T
    }
    
    func set<T>(_ key: String, to value: T?)
        where T: Encodable
    {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let value = value {
            self.storage[key] = value
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
    
    func get<T>(_ key: String, as type: T.Type) -> EventLoopFuture<T?>
        where T: Decodable
    {
        self.eventLoop.makeSucceededFuture(self.storage.get(key))
    }
    
    func set<T>(_ key: String, to value: T?) -> EventLoopFuture<Void>
        where T: Encodable
    
    {
        self.storage.set(key, to: value)
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func `for`(_ request: Request) -> MemoryCache {
        .init(storage: self.storage, on: request.eventLoop)
    }
}
