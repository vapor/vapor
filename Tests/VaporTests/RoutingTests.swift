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
    
    func testCollections() throws {
        let drop = try Droplet()
        XCTAssertEqual(drop.router.routes.count, 0)
        try drop.collection(TestCollectionA.self)
        XCTAssertEqual(drop.router.routes.count, 1)
        try drop.collection(TestCollectionB())
        XCTAssertEqual(drop.router.routes.count, 2)
        
    }
}

private final class TestMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        return try next.respond(to: request)
    }
}

fileprivate final class TestCollectionA: RouteCollection, EmptyInitializable {
    func build(_ builder: RouteBuilder) {
        builder.get("foo") { req in
            return "bar"
        }
    }
}

fileprivate final class TestCollectionB: RouteCollection {
    func build(_ builder: RouteBuilder) {
        builder.get("baz") { req in
            return "bar"
        }
    }
}
