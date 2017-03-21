import HTTP
@testable import Vapor
import XCTest

class HeadMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testHeadRequestResponseBody", testHeadRequestResponseBody),
        ("testHeadRequestMethodMapping", testHeadRequestMethodMapping)
    ]

    func testHeadRequestResponseBody() throws {
        let droplet = try Droplet()

        droplet.get { _ in return "Hello World!" }

        let response = droplet.respond(to: Request(method: .head, path: "/"))

        XCTAssert(response.body.bytes?.count == 0)
    }

    func testHeadRequestMethodMapping() throws {
        let droplet = try Droplet()

        var successfulMapping = false

        droplet.get { _ in
            successfulMapping = true
            return "Hello World!"
        }

        let _ = droplet.respond(to: Request(method: .head, path: "/"))

        XCTAssertTrue(successfulMapping)
    }
}