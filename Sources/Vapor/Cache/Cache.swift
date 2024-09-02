import NIOCore
/// Codable key-value pair cache.
public protocol Cache {
    /// Creates a request-specific cache instance.
    func `for`(_ request: Request) -> Self
    
    /// Gets a decodable value from the cache. Returns `nil` if not found.
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Decodable

    /// Sets an encodable value into the cache. Existing values are replaced. If `nil`, removes value.
    func set<T>(_ key: String, to value: T?) async throws where T: Encodable

    /// Sets an encodable value into the cache with an expiry time. Existing values are replaced. If `nil`, removes value.
    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) async throws where T: Encodable
    
    func delete(_ key: String) async throws

    /// Gets a decodable value from the cache. Returns `nil` if not found.
    func get<T>(_ key: String) async throws -> T? where T: Decodable
}
