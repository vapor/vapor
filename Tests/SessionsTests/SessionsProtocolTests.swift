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
        let id = try s.makeIdentifier()

        XCTAssertNil(s.get(identifier: id))

        s.set(Session(identifier: id, data: Node("bar")))
        XCTAssertEqual(s.get(identifier: id)?.data.string, "bar")

        try s.destroy(identifier: id)
        XCTAssertNil(s.get(identifier: id))
    }

    func testCache() throws {
        let m = MemoryCache()
        let s = CacheSessions(m)
        let id = try s.makeIdentifier()

        XCTAssertNil(try s.get(identifier: id))

        try s.set(Session(identifier: id, data: Node("bar")))
        XCTAssertEqual(try s.get(identifier: id)?.data.string, "bar")

        try s.destroy(identifier: id)
        XCTAssertNil(try s.get(identifier: id))
    }
    
    func testCacheObject() throws {
        let memory = MemoryCache()
        let sessions = CacheSessions(memory)
        let id = try sessions.makeIdentifier()
        
        XCTAssert(try sessions.contains(identifier: id) == false)

        let session = Session(identifier: id)
        try session.data.set("foo", "bar")
        try sessions.set(session)

        let fetched = try sessions.get(identifier: id)
        XCTAssertEqual(try fetched?.data.get("foo"), "bar")

        try sessions.destroy(identifier: id)
        XCTAssert(try sessions.get(identifier: id) == nil)
    }
}
