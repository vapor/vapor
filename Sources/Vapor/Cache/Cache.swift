/// Codable key-value pair cache.
public protocol Cache {
    /// Gets a decodable value from the cache. Returns `nil` if not found.
    func get<T>(_ key: String, as type: T.Type) -> EventLoopFuture<T?>
        where T: Decodable
    
    /// Sets an encodable value into the cache. Existing values are replaced. If `nil`, removes value.
    func set<T>(_ key: String, to value: T?) -> EventLoopFuture<Void>
        where T: Encodable
    
    /// Creates a request-specific cache instance.
    func `for`(_ request: Request) -> Self
}

extension Cache {
    /// Gets a decodable value from the cache. Returns `nil` if not found.
    public func get<T>(_ key: String) -> EventLoopFuture<T?>
        where T: Decodable
    {
        return self.get(key, as: T.self)
    }
}
