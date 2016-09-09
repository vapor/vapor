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
                "date"
            ]
        ])

        let drop = Droplet(config: config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let response = try drop.respond(to: req)

        XCTAssert(response.headers["Date"] != nil)
    }

    func testConfigDateMissing() throws {
        let config = Config([
            "middleware": [
                "abort"
            ]
        ])

        let drop = Droplet(config: config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let response = try drop.respond(to: req)

        XCTAssert(response.headers["Date"] == nil)
    }

    func testConfigDateProvided() throws {
        let drop = Droplet(middleware: [
            "foo": DateMiddleware()
        ])
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let response = try drop.respond(to: req)

        XCTAssert(response.headers["Date"] != nil)
    }
}
