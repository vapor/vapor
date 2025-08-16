import Foundation
import NIOCore
import NIOConcurrencyHelpers

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

internal struct MemoryCache: Cache {
    fileprivate let storage: MemoryCacheStorage

    init() {
        self.storage = MemoryCacheStorage()
    }
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Decodable & Sendable {
        await self.storage.get(key)
    }
    
    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) async throws where T: Encodable & Sendable {
        await self.storage.set(key, to: value, expiresIn: expirationTime)
    }
}
