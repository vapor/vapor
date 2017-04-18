@testable import Vapor // not @testable to ensure Middleware classes are public
import XCTest
import HTTP

extension String: Swift.Error {}

class MiddlewareTests: XCTestCase {
    static let allTests = [
        ("testConfigDate", testConfigDate),
        ("testConfigDateMissing", testConfigDateMissing),
        ("testConfigDateProvided", testConfigDateProvided),
        ("testMultiple", testMultiple),
        ("testConfigClient", testConfigClient),
        ("testConfigClientNotEnabled", testConfigClientNotEnabled),
    ]

    func testConfigDate() throws {
        let config = Config([
            "middleware": [
                "date"
            ]
        ])

        let drop = try Droplet(config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["Date"] != nil)
    }

    func testConfigDateMissing() throws {
        var config = Config([:])
        try config.set("droplet.middleware", ["error"])

        let drop = try Droplet(config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["Date"] == nil)
    }

    func testConfigDateProvided() throws {
        var config = Config([:])
        try config.addOverride(middleware: [
            FooMiddleware()
        ])
        let drop = try Droplet(config)

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testMultiple() throws {
        var config = Config([:])
        try config.addOverride(middleware: [
            FooMiddleware(),
            DateMiddleware()
        ])
        let drop: Droplet
        do {
            drop = try Droplet(config)
        } catch {
            XCTFail("\(error)")
            return
        }

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["bar"] != nil)
        XCTAssert(res.headers["date"] != nil)
    }

    func testConfigClient() throws {
        let foo = FooMiddleware()

        let res = try EngineClient.factory.get("http://httpbin.org/headers", through: [foo])

        // test to make sure basic server saw the
        // header the middleware added
        XCTAssert(try res.bodyString().contains("Foo") == true)
        XCTAssert(try res.bodyString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testConfigClientNotEnabled() throws {
        var config = Config([:])
        try config.addOverride(middleware: [FooMiddleware()])
        let drop = try Droplet()

        let res = try drop.client.request(.get, "http://httpbin.org/headers")

        XCTAssert(try res.bodyString().contains("Foo") != true)
        XCTAssert(try res.bodyString().contains("bar") != true)
        XCTAssertNil(res.headers["bar"])
    }
}

class FooMiddleware: Middleware {
    init() {}
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        request.headers["foo"] = "bar"
        let response = try next.respond(to: request)
        response.headers["bar"] = "baz"
        return response
    }
}
