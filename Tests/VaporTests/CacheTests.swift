import XCTVapor

final class CacheTests: XCTestCase {
    func testDefaultCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        try XCTAssertNil(app.cache.get("foo", as: String.self).wait())
        try app.cache.set("foo", to: "bar").wait()
        try XCTAssertEqual(app.cache.get("foo").wait(), "bar")
    }
    
    func testCustomCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.caches.use(.foo)
        try XCTAssertEqual(app.cache.get("foo").wait(), "bar")
    }
}

extension Application.Caches.Provider {
    static var foo: Self {
        .init { $0.caches.use { FooCache(on: $0.eventLoopGroup.next()) } }
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
    
    func set<T>(_ key: String, to value: T?) -> EventLoopFuture<Void> where T : Encodable {
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func `for`(_ request: Request) -> FooCache {
        return self
    }
}
