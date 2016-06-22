import XCTest
@testable import Vapor

public class TestMiddleware: Middleware {

	public init() {
	}

	public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
		return try chain.respond(to: request)
	}
	
}

class RouteTests: XCTestCase {
    static let allTests = [
       ("testNestedRouteScopedPrefixPopsCorrectly", testNestedRouteScopedPrefixPopsCorrectly),
       ("testRoute", testRoute),
       ("testRouteScopedPrefix", testRouteScopedPrefix)
    ]

    func testRoute() {

        let app = Application()

        app.get("foo") { request in
            return ""
        }

        app.post("bar") { request in
            return ""
        }

        assertRouteExists(at: "foo", method: .get, host: "*", inRoutes: app.routes)
        assertRouteExists(at: "bar", method: .post, host: "*", inRoutes: app.routes)
    }


    func testRouteScopedPrefix() {
        let app = Application()

        app.grouped("group/path") { group in
            group.get("1") { request in
                return ""
            }

            group.options("2") { request in
                return ""
            }
        }

        assertRouteExists(at: "group/path/1", method: .get, host: "*", inRoutes: app.routes)
        assertRouteExists(at: "group/path/2", method: .options, host: "*", inRoutes: app.routes)
    }

    func testNestedRouteScopedPrefixPopsCorrectly() {
        let app = Application()

        app.grouped("group") { group in
            group.grouped("subgroup") { subgroup in
                subgroup.get("1") { request in
                    return ""
                }
            }

            group.options("2") { request in
                return ""
            }
        }

        assertRouteExists(at: "group/subgroup/1", method: .get, host: "*", inRoutes: app.routes)
        assertRouteExists(at: "group/2", method: .options, host: "*", inRoutes: app.routes)
    }

	func testNestedRouteMiddlewareScopedPrefixPopsCorrectly() {
		let app = Application()

		app.grouped("group") { group in
			group.grouped("subgroup") { subgroup in
				subgroup.grouped(TestMiddleware()) { (middlewareGroup) in
					middlewareGroup.get("1") { request in
						return ""
					}
				}
			}
		}

		assertRouteExists(at: "group/subgroup/1", method: .get, host: "*", inRoutes: app.routes)
	}

    func testRouteAbort() throws {
        let app = Application()

        app.get("400") { request in
            print("from 400")
            throw Abort.badRequest
        }

        let request = try Request(method: .get, path: "400")
        guard var handler = app.router.route(request) else {
            XCTFail("No handler found")
            return
        }

        do {
            _ = try handler.respond(to: request)
            XCTFail("Handler did not throw error")
        } catch Abort.badRequest {
            //pass
        } catch {
            XCTFail("Handler threw incorrect error")
        }

        handler = AbortMiddleware().chain(to: handler)

        do {
            let request = try handler.respond(to: request)
            XCTAssert(request.status.statusCode == 400, "Incorrect response status")
        } catch {
            XCTFail("Middleware did not handle abort")
        }
    }

}

/**
 Global functions because any function that takes an argument on an XCTest class fails on Linux.
 */

internal func assertRouteExists(at path: String,
                                method: Vapor.Method,
                                host: String,
                                inRoutes routes: [Route]) {
    var found = false

    for route in routes {
        if route.path == path && route.method == method && route.hostname == host {
            found = true
        }

    }

    if !found {
        XCTFail("\(method) \(path) was not found")
    }
}
