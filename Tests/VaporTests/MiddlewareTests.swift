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
        ("testConfigClientManual", testConfigClientManual),
        ("testValidationMiddleware", testValidationMiddleware),
    ]

    func testConfigDate() throws {
        let config = Config([
            "middleware": [
                "server": [
                    "date"
                ]
            ]
        ])

        let drop = try Droplet(config: config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = drop.respond(to: req)

        XCTAssert(res.headers["Date"] != nil)
    }

    func testConfigDateMissing() throws {
        var config = Config([:])
        try config.set("droplet.middleware.server", ["abort"])

        let drop = try Droplet(config: config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = drop.respond(to: req)

        XCTAssert(res.headers["Date"] == nil)
    }

    func testConfigDateProvided() throws {
        let drop = try Droplet()
        drop.middleware.append(FooMiddleware())

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = drop.respond(to: req)

        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testMultiple() throws {
        let drop = try Droplet()

        drop.middleware = [
            FooMiddleware(),
            DateMiddleware()
        ]

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = drop.respond(to: req)

        XCTAssert(res.headers["bar"] != nil)
        XCTAssert(res.headers["date"] != nil)
    }

    func testConfigClient() throws {
        var config = Config([:])
        try config.set("droplet.middleware.client", ["foo"])

        let drop = try Droplet(config: config)
        drop.addConfigurable(middleware: FooMiddleware(), name: "foo")

        let res = try drop.client.get("http://httpbin.org/headers")

        // test to make sure basic server saw the
        // header the middleware added
        XCTAssert(try res.bodyString().contains("Foo") == true)
        XCTAssert(try res.bodyString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testDynamicConfigClient() throws {
        let drop = try Droplet(config: [:])
        func compare(expectation: Bool) throws {
            let res = try drop.client.get("http://httpbin.org/headers")

            // test to make sure basic server saw the
            // header the middleware added
            XCTAssert(try res.bodyString().contains("Foo") == expectation)
            XCTAssert(try res.bodyString().contains("bar") == expectation)

            // test to make sure the middleware
            // added headers to the response
            let headerCheck = res.headers["bar"] == "baz"
            XCTAssert(headerCheck == expectation)
        }

        try compare(expectation: false)
        drop.addConfigurable(middleware: FooMiddleware(), name: "foo")
        try compare(expectation: false)
        drop.config["droplet.middleware.client"] = ["foo"]
        try compare(expectation: true)
    }

    func testConfigClientNotEnabled() throws {
        let drop = try Droplet()

        drop.client.defaultMiddleware = []
        drop.middleware.append(FooMiddleware())

        let res = try drop.client.get("http://httpbin.org/headers")

        XCTAssert(try res.bodyString().contains("Foo") != true)
        XCTAssert(try res.bodyString().contains("bar") != true)
        XCTAssertNil(res.headers["bar"])
    }

    func testConfigClientManual() throws {
        let drop = try Droplet()
        drop.client.defaultMiddleware = [FooMiddleware()]


        let res = try drop.client.get("http://httpbin.org/headers")
        XCTAssert(res.headers["bar"] != nil)
    }

    func testValidationMiddleware() throws {
        let drop = try Droplet()

        drop.middleware.append(ValidationMiddleware())
        
        drop.get("*") { req in
            let path = req.uri.path
            try path.validated(by: Count.max(10))
            return path
        }

        // only added validation, abort won't be caught.
        drop.get("uncaught") { _ in throw Abort.notFound }

        let request = Request(method: .get, path: "thisPathIsWayTooLong")
        let response = drop.respond(to: request)
        let json = response.json
        XCTAssertEqual(json?["error"]?.bool, true)
        XCTAssertEqual(json?["message"]?.string, "Validation failed with the following errors: \'Validator Error: Count<String> failed validation: thisPathIsWayTooLong count 20 is greater than maximum 10\n\nIdentifier: Vapor.ValidatorError.failure\'")
        let fail = Request(method: .get, path: "uncaught")
        let failResponse = drop.respond(to: fail)
        XCTAssertEqual(failResponse.status, .notFound)
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
