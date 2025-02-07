import NIOCore

extension Cache {

    /// Gets a decodable value from the cache. Returns `nil` if not found.
    public func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Decodable & Sendable {
        try await self.get(key, as: type).get()
    }

    /// Sets an encodable value into the cache. Existing values are replaced. If `nil`, removes value.
    public func set<T>(_ key: String, to value: T?) async throws where T: Encodable & Sendable {
        try await self.set(key, to: value).get()
    }

    /// Sets an encodable value into the cache with an expiry time. Existing values are replaced. If `nil`, removes value.
    public func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) async throws
    where T: Encodable & Sendable {
        try await self.set(key, to: value, expiresIn: expirationTime).get()
    }

    public func delete(_ key: String) async throws {
        try await self.delete(key).get()
    }

    /// Gets a decodable value from the cache. Returns `nil` if not found.
    public func get<T>(_ key: String) async throws -> T? where T: Decodable & Sendable {
        try await self.get(key).get()
    }
}
