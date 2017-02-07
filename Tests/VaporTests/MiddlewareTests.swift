@testable import Vapor // not @testable to ensure Middleware classes are public
import XCTest
import HTTP

extension String: Swift.Error {}

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
        let drop = Droplet()
        drop.middleware.append(FooMiddleware())

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testMultiple() throws {
        let drop = Droplet()

        drop.middleware = [
            FooMiddleware(),
            DateMiddleware()
        ]

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

        let drop = Droplet(config: config)
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

    func testConfigClientNotEnabled() throws {
        let drop = Droplet()

        drop.client.defaultMiddleware = []
        drop.middleware.append(FooMiddleware())

        let res = try drop.client.get("http://httpbin.org/headers")

        XCTAssert(try res.bodyString().contains("Foo") != true)
        XCTAssert(try res.bodyString().contains("bar") != true)
        XCTAssertNil(res.headers["bar"])
    }

    func testConfigClientManual() throws {
        let drop = Droplet()
        drop.client.defaultMiddleware = [FooMiddleware()]


        let res = try drop.client.get("http://httpbin.org/headers")
        XCTAssert(res.headers["bar"] != nil)
    }

    func testAbortMiddleware() throws {
        let drop = Droplet()

        drop.middleware = [AbortMiddleware(environment: .development)]

        drop.get("*") { req in
            let path = req.uri.path
            print(path)
            switch path {
            case "bad":
                throw Abort.badRequest
            case "notFound":
                throw Abort.notFound
            case "server":
                throw Abort.serverError
            default:
                throw Abort.custom(status: Status(statusCode: 42), message: path)
            }
        }

        let expectations: [(path: String, message: String, code: Int, status: Status)] = [
            ("bad", "Invalid request", 400, .badRequest),
            ("notFound", "Page not found", 404, .notFound),
            ("server", "Something went wrong", 500, .internalServerError),
            ("custom", "custom", 42, Status(statusCode: 42))
        ]

        try expectations.forEach { path, expectedMessage, expectedCode, expectedStatus in
            let request = Request(method: .get, path: path)
            let result = try drop.respond(to: request)
            
            guard let message = result.data["message"]?.string else {
                XCTFail("Message should not be nil")
                return
            }
            
            guard let code = result.data["code"]?.int else {
                XCTFail("Code shoult not be nil")
                return
            }
            
            XCTAssertEqual(message, expectedMessage)
            XCTAssertEqual(code, expectedCode)
            XCTAssertEqual(result.status, expectedStatus)
            XCTAssertNil(result.data["metadata"]?.object)
        }


        let request = Request(method: .get, path: "Custom Message")
        request.headers["Accept"] = "html"
        let result = try drop.respond(to: request)
        XCTAssertEqual(result.body.bytes?.string.contains("Custom Message"), true)
    }


    func testValidationMiddleware() throws {
        let drop = Droplet()

        drop.middleware.append(ValidationMiddleware())
        
        drop.get("*") { req in
            let validPath = try req.uri.path.validated(by: Count.max(10))
            return validPath.value
        }

        // only added validation, abort won't be caught.
        drop.get("uncaught") { _ in throw Abort.notFound }

        let request = Request(method: .get, path: "12345678910")
        let response = try drop.respond(to: request)
        let json = try response.body.bytes.flatMap(JSON.init)
        XCTAssertEqual(json?["error"]?.bool, true)
        XCTAssertEqual(json?["message"]?.string, "Validating max(10) failed for input '12345678910'")

        let fail = Request(method: .get, path: "uncaught")
        let failResponse = try drop.respond(to: fail)
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
