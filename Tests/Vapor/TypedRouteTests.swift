//
//  RouterTests.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/18/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest
@testable import Vapor

class Post: StringInitializable {

    required init?(from string: String) throws {
        return nil
    }

}

class TypedRouteTests: XCTestCase {

    static var allTests: [(String, TypedRouteTests -> () throws -> Void)] {
        return [
           ("testRouting", testRouting),
        ]
    }

    func testRouting() {

        let app = Application()


        app.get("users", Int.self) { request, userId in
            return ""
        }

        app.put("posts", Post.self) { request, post in
            return ""
        }

        app.delete("one", Int.self, "two", String.self, "three/four") { request, one, two in
            return ""
        }

        app.host("host.com") {
            app.post("posts", Post.self) { request, post in
                return ""
            }
        }

        app.group("v1") {
            app.patch("posts", Post.self) { request, post in
                return ""
            }
        }

        self.assertRouteExists("users/:w0", method: .get, host: "*", inRoutes: app.routes)
        self.assertRouteExists("posts/:w0", method: .put, host: "*", inRoutes: app.routes)
        self.assertRouteExists("one/:w0/two/:w1/three/four", method: .delete, host: "*", inRoutes: app.routes)
        self.assertRouteExists("posts/:w0", method: .post, host: "host.com", inRoutes: app.routes)
        self.assertRouteExists("v1/posts/:w0", method: .patch, host: "*", inRoutes: app.routes)
    }

    func assertRouteExists(path: String, method: Request.Method, host: String, inRoutes routes: [Route]) {
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
}
