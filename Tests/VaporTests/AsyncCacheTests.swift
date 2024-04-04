import XCTVapor
import XCTest
import Vapor
import NIOCore

final class AsyncCacheTests: XCTestCase {
    func testInMemoryCache() async throws {
        let app = await Application(.testing)
        defer { app.shutdown() }

        let value1 = try await app.cache.get("foo", as: String.self)
        XCTAssertNil(value1)
        try await app.cache.set("foo", to: "bar")
        let value2: String? = try await app.cache.get("foo")
        XCTAssertEqual(value2, "bar")

        // Test expiration
        try await app.cache.set("foo2", to: "bar2", expiresIn: .seconds(1))

        let value3: String? = try await app.cache.get("foo2")
        XCTAssertEqual(value3, "bar2")
        sleep(1)
        let value4 = try await app.cache.get("foo2", as: String.self)
        XCTAssertNil(value4)
        
        // Test reset value
        try await app.cache.set("foo3", to: "bar3")
        let value5: String? = try await app.cache.get("foo3")
        XCTAssertEqual(value5, "bar3")
        try await app.cache.delete("foo3")
        let value6 = try await app.cache.get("foo3", as: String.self)
        XCTAssertNil(value6)
    }

    func testCustomCache() async throws {
        let app = await Application(.testing)
        defer { app.shutdown() }
        app.caches.use(.foo)
        try await app.cache.set("1", to: "2")
        let value = try await app.cache.get("foo", as: String.self)
        XCTAssertEqual(value, "bar")
    }
}

extension Application.Caches.Provider {
    static var foo: Self {
        .init { $0.caches.use { FooCache(on: $0.eventLoopGroup.any()) } }
    }
}

// Always returns "bar" for key "foo".
// That's all...
struct FooCache: Cache {
    let eventLoop: EventLoop
    init(on eventLoop: EventLoop) {
        self.eventLoop = eventLoop
    }

    func get<T>(_ key: String, as type: T.Type) -> EventLoopFuture<T?>
        where T : Decodable
    {
        let value: T?
        if key == "foo" {
            value = "bar" as? T
        } else {
            value = nil
        }
        return self.eventLoop.makeSucceededFuture(value)
    }
    
    func get<T>(_ key: String, as type: T.Type) async throws -> T? where T: Decodable {
        return key == "foo" ? "bar" as? T : nil
    }

    func set<T>(_ key: String, to value: T?) -> EventLoopFuture<Void> where T : Encodable {
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func set<T>(_ key: String, to value: T?) async throws where T: Encodable {
        return
    }

    func `for`(_ request: Request) -> FooCache {
        return self
    }
}
