import XCTest
import Foundation
import Cache
import Dispatch

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
        try cache.set("hello", to: .string("world"), expiration: nil)
        try XCTAssertEqual(cache.get("hello").string, "world")
    }

    func testDelete() throws {
        try cache.set("ephemeral", to: .string("42"), expiration: nil)
        try XCTAssertEqual(cache.get("ephemeral").string, "42")
        try cache.delete("ephemeral")
        try XCTAssertEqual(cache.get("ephemeral"), CacheData.null)
    }

    func testExpiration() throws {
        try cache.set("ephemeral", to: .string("42"), expiration: Date(timeIntervalSinceNow: 0.5))
        try XCTAssertEqual(cache.get("ephemeral").string, "42")
        
        let exp = expectation(description: "cache")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            try! XCTAssertTrue(self.cache.get("ephemeral").isNull)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
}
