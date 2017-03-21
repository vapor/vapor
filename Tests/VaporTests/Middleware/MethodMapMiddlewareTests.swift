import HTTP
import Vapor
import XCTest

class MethodMapMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testMethodMappedRequests", testMethodMappedRequests),
        ("testNormalRequests", testNormalRequests),
        ("testMethodMapHeadMiddlewareInteraction", testMethodMapHeadMiddlewareInteraction),
        ("testHeadMethodMap", testHeadMethodMap),
        ("testResourceMethodMapping", testResourceMethodMapping)
    ]

    func testMethodMappedRequests() throws {
        // Any request to a mapped HTTP method should return the mapped value's response.
        // e.g. A [.get: .put] map should return the PUT handler response from a GET request

        let droplet = try Droplet()

        droplet.middleware.append(MethodMapMiddleware(
            [
                .get: .put,
                .options: .delete,
                .patch: .post
            ]))

        var successCount = 0

        droplet.put { _ in
            successCount += 1
            return "Hello World!"
        }
        droplet.delete { _ in
            successCount += 1
            return "Hello World!"
        }
        droplet.post { _ in
            successCount += 1
            return "Hello World!"
        }

        let _ = droplet.respond(to: Request(method: .get, path: "/"))
        let _ = droplet.respond(to: Request(method: .options, path: "/"))
        let _ = droplet.respond(to: Request(method: .patch, path: "/"))

        XCTAssert(successCount == 3)
    }

    func testNormalRequests() throws {
        // Normal requests to a mapped method value should behave as usual.
        // All other requests should also behave as usual

        let droplet = try Droplet()

        droplet.middleware.append(MethodMapMiddleware([.put: .patch]))

        var successCount = 0

        droplet.patch { _ in
            successCount += 1
            return "Hello World!"
        }
        droplet.add(.connect) { _ in
            successCount += 1
            return "Hello World!"
        }

        let _ = droplet.respond(to: Request(method: .patch, path: "/"))
        let _ = droplet.respond(to: Request(method: .connect, path: "/"))

        XCTAssert(successCount == 2)
    }

    func testMethodMapHeadMiddlewareInteraction() throws {
        // By default, the HeadMiddleware should always work even if someone was to map the head response

        let droplet = try Droplet()

        // even if someone is to add this, the HeadMiddleware should still work
        droplet.middleware.append(MethodMapMiddleware([.head: .patch]))

        var successfulInteraction = true

        droplet.get { _ in return "Hello World!" }
        droplet.patch { _ in
            successfulInteraction = false
            return "Hello World!"
        }

        let response = droplet.respond(to: Request(method: .head, path: "/"))

        XCTAssertTrue(successfulInteraction)
        XCTAssert(response.status.statusCode == 200)
    }

    func testHeadMethodMap() throws {
        // If the HeadMiddleware is disabled, then the MethodMapMiddleware should work for HEAD requests too
        // This is not a good practice, and breaks HTTP specification, but it's good to have this for thorough testing

        let droplet = try Droplet()

        droplet.middleware = []
        droplet.middleware.append(MethodMapMiddleware([.head: .patch]))

        var successfulMapping = false

        droplet.patch { _ in
            successfulMapping = true
            return "Hello World!"
        }

        let response = droplet.respond(to: Request(method: .head, path: "/"))

        XCTAssertTrue(successfulMapping)
        XCTAssert(try response.bodyString() == "Hello World!")
    }

    func testResourceMethodMapping() throws {
        // Method mapping should also work for resources

        let droplet = try Droplet()

        droplet.middleware.append(MethodMapMiddleware([.put: .patch]))

        var successfulMapping = false

        droplet.resource("users", User.self) { users in
            users.modify = { req in
                successfulMapping = true
                return "Hello World!"
            }
        }

        let _ = droplet.respond(to: Request(method: .put, path: "/users/bob"))

        XCTAssertTrue(successfulMapping)
    }
}
