import XCTVapor
import XCTest
import Vapor
import NIOCore

@available(*, deprecated, message: "Test old future APIs")
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
        sleep(2)
        try XCTAssertNil(app.cache.get("foo2", as: String.self).wait())
        
        // Test reset value
        try app.cache.set("foo3", to: "bar3").wait()
        try XCTAssertEqual(app.cache.get("foo3").wait(), "bar3")
        try app.cache.delete("foo3").wait()
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
