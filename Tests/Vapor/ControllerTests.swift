//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

private class TestController: Controller {
    required init(application: Application) {
        print("TestController online")
    }

    static var lock: (
        index: Int,
        store: Int,
        show: Int,
        update: Int,
        destroy: Int
        ) = (0, 0, 0, 0, 0)

    /// Display many instances
    func index(_ request: Request) throws -> ResponseRepresentable {
        TestController.lock.index += 1
        return "index"
    }

    /// Create a new instance.
    func store(_ request: Request) throws -> ResponseRepresentable {
        TestController.lock.store += 1
        return "store"
    }

    /// Show an instance.
    func show(_ request: Request, item: String) throws -> ResponseRepresentable {
        TestController.lock.show += 1
        return "show"
    }

    /// Update an instance.
    func update(_ request: Request, item: String) throws -> ResponseRepresentable {
        TestController.lock.update += 1
        return "update"
    }

    /// Delete an instance.
    func destroy(_ request: Request, item: String) throws -> ResponseRepresentable {
        TestController.lock.destroy += 1
        return "destroy"
    }

}

class ControllerTests: XCTestCase {

    static var allTests: [(String, ControllerTests -> () throws -> Void)] {
        return [
            ("testController", testController)
        ]
    }

    func testController() {

        let app = Application()

        app.resource("foo", controller: TestController.self)

        app.bootRoutes()

        let fooIndex = Request(method: .get, uri: URI(path: "foo"), headers: [:], body: [])
        if let (_, handler) = app.router.route(fooIndex) {
            do {
                try handler.respond(to: fooIndex)
                XCTAssert(TestController.lock.index == 1, "foo.index Lock not correct")
            } catch {
                XCTFail("foo.index handler failed")
            }
        } else {
            XCTFail("No handler found for foo.index")
        }

    }

}
