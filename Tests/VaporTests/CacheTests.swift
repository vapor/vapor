import Testing
import VaporTesting
import Vapor
import NIOCore

@Suite("Cache Tests")
struct CacheTests {
    @Test("Test the In Memory Cache")
    func inMemoryCache() async throws {
        try await withApp { app in
            let value1 = try await app.cache.get("foo", as: String.self)
            #expect(value1 == nil)
            try await app.cache.set("foo", to: "bar", expiresIn: nil)
            let value2: String? = try await app.cache.get("foo")
            #expect(value2 == "bar")

            // Test expiration
            try await app.cache.set("foo2", to: "bar2", expiresIn: .seconds(1))

            let value3: String? = try await app.cache.get("foo2")
            #expect(value3 == "bar2")
            try await Task.sleep(for: .seconds(1))
            let value4 = try await app.cache.get("foo2", as: String.self)
            #expect(value4 == nil)

            // Test reset value
            try await app.cache.set("foo3", to: "bar3", expiresIn: nil)
            let value5: String? = try await app.cache.get("foo3")
            #expect(value5 == "bar3")
            try await app.cache.delete("foo3")
            let value6 = try await app.cache.get("foo3", as: String.self)
            #expect(value6 == nil)
        }
    }

    @Test("Test Custom Cache")
    func customCache() async throws {
        try await withApp(services: .init(cache: .provided(FooCache()))) { app in
            try await app.cache.set("1", to: "2", expiresIn: nil)
            let value = try await app.cache.get("foo", as: String.self)
            #expect(value == "bar")
        }
    }
}


// Always returns "bar" for key "foo".
// That's all...
struct FooCache: Cache {
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Decodable & Sendable {
        return key == "foo" ? "bar" as? T : nil
    }

    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) async throws where T : Encodable, T : Sendable {}
}
