import XCTVapor
import XCTest
import Vapor
import NIOCore

final class EndpointCacheTests: XCTestCase {
    func testEndpointCacheNoCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let current = NumberHolder()
        class NumberHolder {
            var number = 0
        }
        
        struct Test: Content {
            let number: Int
        }

        app.get("number") { req -> Test in
            defer { current.number += 1 }
            return Test(number: current.number)
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

        let current = NumberHolder()
        class NumberHolder {
            var number = 0
        }
        struct Test: Content {
            let number: Int
        }

        app.clients.use(.responder)

        app.get("number") { req -> Response in
            defer { current.number += 1 }
            let res = Response()
            try res.content.encode(Test(number: current.number))
            res.headers.cacheControl = .init(maxAge: 1)
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
