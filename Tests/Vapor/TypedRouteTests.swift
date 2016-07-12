import Foundation
import XCTest
@testable import Vapor

class Post: StringInitializable {
    required init?(from string: String) throws {
        return nil
    }
}

class TypedRouteTests: XCTestCase {

    static let allTests = [
       ("testRouting", testRouting),
   ]

    func testRouting() {

        let drop = Droplet()


        drop.get("users", Int.self) { request, userId in
            return ""
        }

        drop.put("posts", Post.self) { request, post in
            return ""
        }

        drop.delete("one", Int.self, "two", String.self, "three/four") { request, one, two in
            return ""
        }

        drop.grouped("v1") { group in
            group.patch("posts", Post.self) { request, post in
                return ""
            }
        }

        assertRouteExists(at: "users/:w0",
                          method: .get,
                          host: "*",
                          inRoutes: drop.routes)
        assertRouteExists(at: "posts/:w0",
                          method: .put,
                          host: "*",
                          inRoutes: drop.routes)
        assertRouteExists(at: "one/:w0/two/:w1/three/four",
                          method: .delete,
                          host: "*",
                          inRoutes: drop.routes)
        assertRouteExists(at: "v1/posts/:w0",
                          method: .patch,
                          host: "*",
                          inRoutes: drop.routes)
    }

}
