import XCTest
import Dispatch
import Async
import Core
@testable import Redis

class RedisTests: XCTestCase {
    static let allTests = [
        ("testCRUD", testCRUD),
    ]
    
    func testCRUD() throws {
        let queue = DispatchQueue(label: "test.kaas")
        
        let connection = try Redis.connect(hostname: "localhost", worker: Worker(queue: queue)).blockingAwait(timeout: .seconds(1))
        
        _ = try connection.delete("*").blockingAwait(timeout: .seconds(1))
        
        let result = try connection.set("world", forKey: "hello").reduce {
            return try connection.getValue(forKey: "hello")
        }.blockingAwait(timeout: .seconds(1))
        
        let removedCount = try connection.delete("hello").blockingAwait(timeout: .seconds(1))
        
        XCTAssertEqual(removedCount, 1)
        
        XCTAssertEqual(result.string, "world")
    }
}
