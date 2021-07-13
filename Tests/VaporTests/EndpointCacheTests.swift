import XCTVapor
import Baggage

final class EndpointCacheTests: XCTestCase {
    func testEndpointCacheNoCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        var current = 0
        struct Test: Content {
            let number: Int
        }

        app.get("number") { req -> Test in
            defer { current += 1 }
            return Test(number: current)
        }

        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        app.clients.use(.responder)

        let cache = EndpointCache<Test>(uri: "/number")
        do {
            let test = try cache.get(
                using: app.client,
                on: app.eventLoopGroup.next(),
                context: context
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        do {
            let test = try cache.get(
                using: app.client,
                on: app.eventLoopGroup.next(),
                context: context
            ).wait()
            XCTAssertEqual(test.number, 1)
        }
    }

    func testEndpointCacheMaxAge() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        var current = 0
        struct Test: Content {
            let number: Int
        }

        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        app.clients.use(.responder)

        app.get("number") { req -> Response in
            defer { current += 1 }
            let res = Response()
            try res.content.encode(Test(number: current))
            res.headers.cacheControl = .init(maxAge: 1)
            return res
        }

        let cache = EndpointCache<Test>(uri: "/number")
        do {
            let test = try cache.get(
                using: app.client,
                on: app.eventLoopGroup.next(),
                context: context
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        do {
            let test = try cache.get(
                using: app.client,
                on: app.eventLoopGroup.next(),
                context: context
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        // wait for expiry
        sleep(1)
        do {
            let test = try cache.get(
                using: app.client,
                on: app.eventLoopGroup.next(),
                context: context
            ).wait()
            XCTAssertEqual(test.number, 1)
        }
    }
}
