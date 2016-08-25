import XCTest
@testable import Cache

class MemoryCacheTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testDelete", testDelete),
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
}
