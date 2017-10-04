import Async

/// A key-value cache
public protocol KeyedCache {
    /// Gets the value as type `D` deserialized from the value associated with the `key`
    ///
    /// Returns an empty future that triggers on successful storage
    func get<D: Decodable>(_ type: D.Type, forKey key: String) throws -> Future<D>
    
    /// Sets the value to `entity` stored associated with the `key`
    ///
    /// Returns an empty future that triggers on successful storage
    func set<E: Encodable>(_ entity: E, forKey key: String) throws -> Future<Void>
    
    /// Removes the value associated with the `key`
    func remove(_ key: String) throws -> Future<Void>
}
