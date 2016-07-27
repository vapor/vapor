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

        let drop = Droplet()

        drop.get("foo") { request in
            return ""
        }

        drop.post("bar") { request in
            return ""
        }

        assertRouteExists(at: "foo", method: .get, host: "*", inRoutes: drop.routes)
        assertRouteExists(at: "bar", method: .post, host: "*", inRoutes: drop.routes)
    }


    func testRouteScopedPrefix() {
        let drop = Droplet()

        drop.grouped("group/path") { group in
            group.get("1") { request in
                return ""
            }

            group.options("2") { request in
                return ""
            }
        }

        assertRouteExists(at: "group/path/1", method: .get, host: "*", inRoutes: drop.routes)
        assertRouteExists(at: "group/path/2", method: .options, host: "*", inRoutes: drop.routes)
    }

    func testNestedRouteScopedPrefixPopsCorrectly() {
        let drop = Droplet()

        drop.grouped("group") { group in
            group.grouped("subgroup") { subgroup in
                subgroup.get("1") { request in
                    return ""
                }
            }

            group.options("2") { request in
                return ""
            }
        }

        assertRouteExists(at: "group/subgroup/1", method: .get, host: "*", inRoutes: drop.routes)
        assertRouteExists(at: "group/2", method: .options, host: "*", inRoutes: drop.routes)
    }

	func testNestedRouteMiddlewareScopedPrefixPopsCorrectly() {
		let drop = Droplet()

		drop.grouped("group") { group in
			group.grouped("subgroup") { subgroup in
				subgroup.grouped(TestMiddleware()) { (middlewareGroup) in
					middlewareGroup.get("1") { request in
						return ""
					}
				}
			}
		}

		assertRouteExists(at: "group/subgroup/1", method: .get, host: "*", inRoutes: drop.routes)
	}

    func testRouteAbort() throws {
        let drop = Droplet()

        drop.get("400") { request in
            print("from 400")
            throw Abort.badRequest
        }
        
        let request = Request(method: .get, path: "400")
        guard var handler = drop.router.route(request) else {
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
                                method: HTTPMethod,
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
