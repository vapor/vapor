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

    required init(application: Application) { }

    static var lock: (
        index: Int,
        store: Int,
        show: Int,
        update: Int,
        destroy: Int,
        destroyAll: Int,
        hello: Int
        ) = (0, 0, 0, 0, 0, 0, 0)

    /**
        Display many instances
     */
    func index(_ request: Request) throws -> ResponseRepresentable {
        TestController.lock.index += 1
        return "index"
    }

    /**
        Create a new instance.
     */
    func store(_ request: Request) throws -> ResponseRepresentable {
        TestController.lock.store += 1
        return "store"
    }
    /**
        Show an instance.
     */
    func show(_ request: Request, item: String) throws -> ResponseRepresentable {
        TestController.lock.show += 1
        return "show"
    }

    /**
        Update an instance.
     */
    func update(_ request: Request, item: String) throws -> ResponseRepresentable {
        TestController.lock.update += 1
        return "update"
    }

    /**
        Delete an instance
     */
    func destroy(_ request: Request, item: String) throws -> ResponseRepresentable {
        TestController.lock.destroy += 1
        return "destroy"
    }

    /**
        Deletes all instances
     */
    func destroyAll(_ request: Request) throws -> ResponseRepresentable {
        TestController.lock.destroyAll += 1
        return "destroyAll"
    }

    func hello(_ request: Request) throws -> ResponseRepresentable {
        TestController.lock.hello += 1
        return "Hello, World!"
    }

}

private class TestActionController: DefaultInitializable {
    static var hello = 0
    let person: String

    init(person: String) {
        self.person = person
    }

    required init() {
        self.person = "World"
    }

    func hello(_ request: Request) throws -> ResponseRepresentable {
        TestActionController.hello += 1
        return "Hello, \(person)!"
    }
}


class ControllerTests: XCTestCase {

    static var allTests: [(String, (ControllerTests) -> () throws -> Void)] {
        return [
            ("testController", testController),
            ("testControllerActionRouting_withFactory", testControllerActionRouting_withFactory),
            ("testControllerActionRouting_withDefaultInitializable", testControllerActionRouting_withDefaultInitializable),
            ("testControllerActionRouting_withApplicationInitializable", testControllerActionRouting_withApplicationInitializable)
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

    func testControllerActionRouting_withFactory() {
        defer { TestActionController.hello = 0 }
        let app = Application()

        app.add(.get, path: "/hello", action: TestActionController.hello) { TestActionController(person: "Tanner") }

        app.bootRoutes()

        let request = Request(method: .get, uri: URI(path: "hello"), headers: [:], body: [])
        guard let (_, handler) = app.router.route(request) else {
            XCTFail("No handler found for TestActionController.hello")
            return
        }

        do {
            try handler.respond(to: request)
            XCTAssertEqual(TestActionController.hello, 1)
        } catch {
            XCTFail("TestActionController.hello handler failed with error '\(error)'")
        }
    }

    func testControllerActionRouting_withDefaultInitializable() {
        defer { TestActionController.hello = 0 }
        let app = Application()

        app.add(.get, path: "/hello", action: TestActionController.hello)

        app.bootRoutes()

        let request = Request(method: .get, uri: URI(path: "hello"), headers: [:], body: [])
        guard let (_, handler) = app.router.route(request) else {
            XCTFail("No handler found for TestActionController.hello")
            return
        }

        do {
            try handler.respond(to: request)
            XCTAssertEqual(TestActionController.hello, 1)
        } catch {
            XCTFail("TestActionController.hello handler failed with error '\(error)'")
        }
    }

    func testControllerActionRouting_withApplicationInitializable() {
        let app = Application()

        app.add(.get, path: "/hello", action: TestController.hello)

        app.bootRoutes()

        let request = Request(method: .get, uri: URI(path: "hello"), headers: [:], body: [])
        guard let (_, handler) = app.router.route(request) else {
            XCTFail("No handler found for TestController.hello")
            return
        }

        do {
            try handler.respond(to: request)
            XCTAssertEqual(TestController.lock.hello, 1)
        } catch {
            XCTFail("TestController.hello handler failed with error '\(error)'")
        }
    }



}
