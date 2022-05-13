import XCTVapor

final class CacheTests: XCTestCase {
    func testInMemoryCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        try XCTAssertNil(app.cache.get("foo", as: String.self).wait())
        try app.cache.set("foo", to: "bar").wait()
        try XCTAssertEqual(app.cache.get("foo").wait(), "bar")
        
        // Test expiration
        try app.cache.set("foo2", to: "bar2", expiresIn: .seconds(1)).wait()
        try XCTAssertEqual(app.cache.get("foo2").wait(), "bar2")
        sleep(1)
        try XCTAssertNil(app.cache.get("foo2", as: String.self).wait())
        
        // Test reset value
        try app.cache.set("foo3", to: "bar3").wait()
        try XCTAssertEqual(app.cache.get("foo3").wait(), "bar3")
        try app.cache.set("foo3", to: nil).wait()
        try XCTAssertNil(app.cache.get("foo3", as: String.self).wait())
    }
    
    func testCustomCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.caches.use(.foo)
        try app.cache.set("1", to: "2").wait()
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
    
    func setToNil(_ key: String) -> EventLoopFuture<Void> {
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func set(_ key: String, to value: ExpressibleByNilLiteral?) -> EventLoopFuture<Void> {
        return self.eventLoop.makeSucceededFuture(())
    }
    
    func `for`(_ request: Request) -> FooCache {
        return self
    }
}
