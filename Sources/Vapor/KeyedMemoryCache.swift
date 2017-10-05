import Async
import Dispatch

/// Stores key-value pair in a dictionary thread-safely
public final class KeyedDictionaryCache: KeyedCache {
    /// The underlying storage of this cache
    var storage = [String: Any]()
    
    /// The cache uses this queue for synchronous thread-safe access
    let queue: DispatchQueue
    
    /// The cache uses the provided queue for synchronous thread-safe access
    public init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    /// Retreived a value from the cache
    public func get<D>(_ type: D.Type, forKey key: String) throws -> Future<D?> where D : Decodable {
        return queue.sync {
            Future(storage[key] as? D)
        }
    }
    
    /// Sets a new value in the cache
    public func set<E>(_ entity: E, forKey key: String) throws -> Future<Void> where E : Encodable {
        queue.sync {
            storage[key] = entity
        }
        
        return Future(())
    }
    
    /// Removes a value from the cache
    public func remove(_ key: String) throws -> Future<Void> {
        queue.sync {
            storage[key] = nil
        }
        
        return Future(())
    }
}
