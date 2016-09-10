import Vapor // not @testable to ensure Middleware classes are public
import XCTest
import HTTP

class MiddlewareTests: XCTestCase {
    static let allTests = [
        ("testConfigDate", testConfigDate),
        ("testConfigDateMissing", testConfigDateMissing),
        ("testConfigDateProvided", testConfigDateProvided),
    ]

    func testConfigDate() throws {
        let config = Config([
            "middleware": [
                "server": [
                    "date"
                ]
            ]
        ])

        let drop = Droplet(config: config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["Date"] != nil)
    }

    func testConfigDateMissing() throws {
        let config = Config([
            "middleware": [
                "server": [
                    "abort"
                ]
            ]
        ])

        let drop = Droplet(config: config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["Date"] == nil)
    }

    func testConfigDateProvided() throws {
        let drop = Droplet(availableMiddleware: [
            "foo": FooMiddleware()
        ])
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testMultiple() throws {
        let drop = Droplet(availableMiddleware: [
            "foo": FooMiddleware()
        ], serverMiddleware: ["foo", "date"])

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["bar"] != nil)
        XCTAssert(res.headers["date"] != nil)
    }

    func testConfigClient() throws {
        let config = Config([
            "middleware": [
                "client": [
                    "foo"
                ]
            ]
        ])

        let drop = Droplet(config: config, availableMiddleware: [
            "foo": FooMiddleware()
        ])

        let res = try drop.client.get("http://httpbin.org/headers")

        // test to make sure basic server saw the
        // header the middleware added
        XCTAssert(try res.bodyString().contains("Foo") == true)
        XCTAssert(try res.bodyString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testConfigClientNotEnabled() throws {
        let drop = Droplet(availableMiddleware: [
            "foo": FooMiddleware()
        ])

        let res = try drop.client.get("http://httpbin.org/headers")

        XCTAssert(try res.bodyString().contains("Foo") != true)
        XCTAssert(try res.bodyString().contains("bar") != true)
        XCTAssertNil(res.headers["bar"])
    }

    func testConfigClientManual() throws {
        let drop = Droplet(availableMiddleware: [
            "foo": FooMiddleware()
        ], clientMiddleware: ["foo"])

        let res = try drop.client.get("http://httpbin.org/headers")
        XCTAssert(res.headers["bar"] != nil)
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
