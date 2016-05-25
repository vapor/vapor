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

    static var allTests: [(String, (TypedRouteTests) -> () throws -> Void)] {
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

        app.grouped("v1") { group in
            group.patch("posts", Post.self) { request, post in
                return ""
            }
        }

        assertRouteExists(at: "users/:w0",
                          method: .get,
                          host: "*",
                          inRoutes: app.routes)
        assertRouteExists(at: "posts/:w0",
                          method: .put,
                          host: "*",
                          inRoutes: app.routes)
        assertRouteExists(at: "one/:w0/two/:w1/three/four",
                          method: .delete,
                          host: "*",
                          inRoutes: app.routes)
        assertRouteExists(at: "v1/posts/:w0",
                          method: .patch,
                          host: "*",
                          inRoutes: app.routes)
    }

}
