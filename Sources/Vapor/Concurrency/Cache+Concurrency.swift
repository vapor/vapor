#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public extension Cache {

    /// Gets a decodable value from the cache. Returns `nil` if not found.
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Decodable {
        try await self.get(key, as: type).get()
    }

    /// Sets an encodable value into the cache. Existing values are replaced. If `nil`, removes value.
    func set<T>(_ key: String, to value: T?) async throws where T: Encodable {
        try await self.set(key, to: value).get()
    }

    /// Sets an encodable value into the cache with an expiry time. Existing values are replaced. If `nil`, removes value.
    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) async throws where T: Encodable {
        try await self.set(key, to: value, expiresIn: expirationTime).get()
    }

    /// Gets a decodable value from the cache. Returns `nil` if not found.
    func get<T>(_ key: String) async throws -> T? where T: Decodable {
        try await self.get(key).get()
    }
}

#endif
