import XCTest
@testable import Vapor
import HTTP
import Routing

class RoutingTests: XCTestCase {
    static let allTests = [
        ("testMiddlewareMethod", testMiddlewareMethod)
    ]

    func testMiddlewareMethod() throws {
        let drop = try Droplet()
        drop.group(TestMiddleware()) { test in
            test.get("foo") { req in
                return "get"
            }

            test.post("foo") { req in
                return "post"
            }
        }

        XCTAssertEqual(try drop.responseBody(for: .get, "/foo"), "get")
        XCTAssertEqual(try drop.responseBody(for: .post, "/foo"), "post")
    }
}

private final class TestMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        return try next.respond(to: request)
    }
}
