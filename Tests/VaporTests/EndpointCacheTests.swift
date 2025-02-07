import NIOCore
import Vapor
import XCTVapor
import XCTest

final class EndpointCacheTests: XCTestCase {

    actor CurrentActor {
        var current = 0

        func increment() {
            self.current += 1
        }

        func getCurrent() -> Int {
            self.current
        }
    }

    func testEndpointCacheNoCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let currentActor = CurrentActor()
        struct Test: Content {
            let number: Int
        }

        app.get("number") { req -> Test in
            let current = await currentActor.getCurrent()
            await currentActor.increment()
            return Test(number: current)
        }

        app.clients.use(.responder)

        let cache = EndpointCache<Test>(uri: "/number")
        do {
            let test = try cache.get(
                using: app.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        do {
            let test = try cache.get(
                using: app.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 1)
        }
    }

    func testEndpointCacheMaxAge() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let currentActor = CurrentActor()
        struct Test: Content {
            let number: Int
        }

        app.clients.use(.responder)

        app.get("number") { req -> Response in
            let res = Response()
            let current = await currentActor.getCurrent()
            try res.content.encode(Test(number: current))
            res.headers.cacheControl = .init(maxAge: 1)
            await currentActor.increment()
            return res
        }

        let cache = EndpointCache<Test>(uri: "/number")
        do {
            let test = try cache.get(
                using: app.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        do {
            let test = try cache.get(
                using: app.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        // wait for expiry
        sleep(1)
        do {
            let test = try cache.get(
                using: app.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 1)
        }
    }
}
