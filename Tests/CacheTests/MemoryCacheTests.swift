import XCTest
import Foundation
@testable import Cache

class MemoryCacheTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testDelete", testDelete),
        ("testExpiration", testExpiration)
    ]

    var cache: MemoryCache!

    override func setUp() {
        cache = MemoryCache()
    }

    func testBasic() throws {
        try cache.set("hello", "world")
        XCTAssertEqual(try cache.get("hello")?.string, "world")
    }

    func testDelete() throws {
        try cache.set("ephemeral", 42)
        XCTAssertEqual(try cache.get("ephemeral")?.string, "42")
        try cache.delete("ephemeral")
        XCTAssertEqual(try cache.get("ephemeral"), nil)
    }

    func testExpiration() throws {
        try cache.set("ephemeral", 42, expiration: Date(timeIntervalSinceNow: 0.5))
        XCTAssertEqual(try cache.get("ephemeral")?.string, "42")
        sleep(1)
        XCTAssertTrue(try cache.get("ephemeral")?.isNull ?? false)
    }
}
