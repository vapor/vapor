import XCTest
import Dispatch
import Async
import TCP
import JunkDrawer
@testable import Redis

class RedisTests: XCTestCase {
    var clientCount = 0

    let queue = DispatchEventLoop(label: "codes.vapor.redis.test")

    func makeClient() throws -> RedisClient {
        return try RedisClient.connect(
            hostname: "localhost",
            on: queue
        )
    }
    
    func testCRUD() throws {
        let connection = try makeClient()
        _ = try connection.delete(
            keys: ["*"]
        ).blockingAwait(timeout: .seconds(10))

        _  = try connection.set("world", forKey: "hello").blockingAwait(timeout: .seconds(10))
        let result = try connection.getData(forKey: "hello").blockingAwait()

        let removedCount = try connection.delete(keys: ["hello"]).blockingAwait(timeout: .seconds(10))

        XCTAssertEqual(removedCount, 1)
        XCTAssertEqual(result.string, "world")
    }

    func testPubSub() throws {
        let promise = Promise<RedisData>()
        let listener = try makeClient()

        _ = listener.subscribe(to: ["test", "test2"]).drain { req in
            req.request()
        }.output { input in
            promise.complete(input.message)
        }.catch(onError: promise.fail)

        let publisher = try makeClient()
        let listeners = try publisher.publish("hello", to: "test").blockingAwait(timeout: .seconds(1))

        XCTAssertEqual(listeners, 1)

        let result = try promise.future.blockingAwait(timeout: .seconds(3))

        XCTAssertEqual(result.string, "hello")

        // Prevent deallocation
        _ = listener
    }
    
    static let allTests = [
        ("testCRUD", testCRUD),
        ("testPubSub", testPubSub),
    ]
}
