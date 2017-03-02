import XCTest
@testable import Sessions
import Core
import Node
import Cache

class SessionsProtocolTests: XCTestCase {
    static let allTests = [
        ("testMemory", testMemory),
        ("testCache", testCache),
        ("testCacheObject", testCacheObject),
    ]

    func testMemory() throws {
        let s = MemorySessions()
        let id = s.makeIdentifier()

        XCTAssertNil(s.get(identifier: id))

        s.set(Session(identifier: id, data: Node("bar")))
        XCTAssertEqual(s.get(identifier: id)?.data.string, "bar")

        try s.destroy(identifier: id)
        XCTAssertNil(s.get(identifier: id))
    }

    func testCache() throws {
        let m = MemoryCache()
        let s = CacheSessions(cache: m)
        let id = s.makeIdentifier()

        XCTAssertNil(try s.get(identifier: id))

        try s.set(Session(identifier: id, data: Node("bar")))
        XCTAssertEqual(try s.get(identifier: id)?.data.string, "bar")

        try s.destroy(identifier: id)
        XCTAssertNil(try s.get(identifier: id))
    }
    
    func testCacheObject() throws {
        let m = MemoryCache()
        let s = CacheSessions(cache: m)
        let id = s.makeIdentifier()
        
        XCTAssertNil(try s.get(for: id))
        
        try s.set(Node(["foo": "bar"]), for: id)
        XCTAssertEqual(try s.get(for: id)?.node["foo"]?.string, "bar")
        
        try s.destroy(id)
        XCTAssertNil(try s.get(for: id))
    }
}
