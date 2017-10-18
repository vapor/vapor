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
        
        _ = try connection.delete(keys: ["*"]).blockingAwait(timeout: .seconds(1))
        
        let result = try connection.set("world", forKey: "hello").flatten {
            return connection.getData(forKey: "hello")
        }.blockingAwait(timeout: .seconds(1))
        
        let removedCount = try connection.delete(keys: ["hello"]).blockingAwait(timeout: .seconds(1))
        
        XCTAssertEqual(removedCount, 1)
        
        XCTAssertEqual(result.string, "world")
    }
}
