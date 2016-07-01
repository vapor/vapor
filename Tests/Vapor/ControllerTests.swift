import XCTest
@testable import Vapor

private class TestController: ApplicationInitializable, Resource {

    required init(droplet: Application) { }

    var lock: (
        index: Int,
        store: Int,
        show: Int,
        replace: Int,
        modify: Int,
        destroy: Int,
        destroyAll: Int,
        options: Int,
        optionsAll: Int
        ) = (0, 0, 0, 0, 0, 0, 0, 0, 0)

    func index(request: Request) throws -> Vapor.ResponseRepresentable {
        lock.index += 1
        return "index"
    }

    func store(request: Request) throws -> Vapor.ResponseRepresentable {
        lock.store += 1
        return "store"
    }

    func show(request: Request, item: String) throws -> Vapor.ResponseRepresentable {
        lock.show += 1
        return "show"
    }

    func replace(request: Request, item: String) throws -> Vapor.ResponseRepresentable {
        lock.replace += 1
        return "update"
    }

    func modify(request: Request, item: String) throws -> Vapor.ResponseRepresentable {
        lock.modify += 1
        return "modify"
    }

    func destroy(request: Request, item: String) throws -> Vapor.ResponseRepresentable {
        lock.destroy += 1
        return "destroy"
    }

    func destroy(request: Request) throws -> Vapor.ResponseRepresentable {
        lock.destroyAll += 1
        return "destroy all"
    }

    func options(request: Request) throws -> Vapor.ResponseRepresentable {
        lock.optionsAll += 1
        return "options all"
    }

    func options(request: Request, item: String) throws -> Vapor.ResponseRepresentable {
        lock.options += 1
        return "options all"
    }
}

private class TestActionController: DefaultInitializable {
    static var helloRunCount = 0
    let person: String

    init(person: String) {
        self.person = person
    }

    required init() {
        self.person = "World"
    }

    func hello(_ request: Request) throws -> Vapor.ResponseRepresentable {
        TestActionController.helloRunCount += 1
        return "Hello, \(person)!"
    }
}


class ControllerTests: XCTestCase {
    static let allTests = [
        ("testController", testController),
        ("testControllerActionRouting_withFactory", testControllerActionRouting_withFactory),
        ("testControllerActionRouting_withDefaultInitializable", testControllerActionRouting_withDefaultInitializable),
        ("testControllerActionRouting_withApplicationInitializable", testControllerActionRouting_withApplicationInitializable),
        ("testControllerMethodsHit", testControllerMethodsHit)
    ]

    func testController() throws {
        let app = Application()

        let instance = TestController(droplet: app)
        app.resource("foo", makeControllerWith: { return instance })

        let fooIndex = try Request(method: .get, path: "foo")
        if let handler = app.router.route(fooIndex) {
            do {
                let _ = try handler.respond(to: fooIndex)
                XCTAssert(instance.lock.index == 1, "foo.index Lock not correct")
            } catch {
                XCTFail("foo.index handler failed")
            }
        } else {
            XCTFail("No handler found for foo.index")
        }
    }

    func testControllerActionRouting_withFactory() throws {
        TestActionController.helloRunCount = 0
        let app = Application()

        app.add(.get, path: "/hello", action: TestActionController.hello) { TestActionController(person: "Tanner") }

        let request = try Request(method: .get, path: "hello")
        guard let handler = app.router.route(request) else {
            XCTFail("No handler found for TestActionController.hello")
            return
        }

        let _ = try handler.respond(to: request)
        XCTAssertEqual(TestActionController.helloRunCount, 1)
    }

    func testControllerActionRouting_withDefaultInitializable() throws {
        TestActionController.helloRunCount = 0
        let app = Application()

        app.add(.get, path: "/hello", action: TestActionController.hello)

        let request = try Request(method: .get, path: "hello")
        guard let handler = app.router.route(request) else {
            XCTFail("No handler found for TestActionController.hello")
            return
        }

        let _ = try handler.respond(to: request)
        XCTAssertEqual(TestActionController.helloRunCount, 1)
    }

    func testControllerActionRouting_withApplicationInitializable() throws {
        TestActionController.helloRunCount = 0

        let app = Application()

        app.add(.get, path: "/hello", action: TestActionController.hello)

        let request = try Request(method: .get, path: "hello")
        guard let handler = app.router.route(request) else {
            XCTFail("No handler found for TestController.hello")
            return
        }

        let _ = try handler.respond(to: request)
        XCTAssertEqual(TestActionController.helloRunCount, 1)
    }


    func testControllerMethodsHit() throws {
        let app = Application()
        // Need single instance to test
        let testInstance = TestController(droplet: app)
        let factory: (Void) -> TestController = { print("blahblah : \(testInstance)"); return testInstance }
        app.resource("/test", makeControllerWith: factory)

        func handleRequest(req: Request) throws {
            guard let handler = app.router.route(req) else { return }
            let _ = try handler.respond(to: req)
        }

        let arrayRequests: [Request] = try [.get, .post, .delete].map {
            return try Request(method: $0, path: "/test", host: "0.0.0.0")
        }

        try arrayRequests.forEach(handleRequest)
        XCTAssert(testInstance.lock.index == 1)
        XCTAssert(testInstance.lock.store == 1)
        XCTAssert(testInstance.lock.destroyAll == 1)
        XCTAssert(testInstance.lock.show == 0)
        XCTAssert(testInstance.lock.replace == 0)
        XCTAssert(testInstance.lock.modify == 0)
        XCTAssert(testInstance.lock.destroy == 0)

        let individualRequests: [Request] = try [.get, .post, .put, .patch, .delete].map {
            return try Request(method: $0, path: "test/123", host: "0.0.0.0")
        }
        try individualRequests.forEach(handleRequest)

        XCTAssert(testInstance.lock.show == 1)
        XCTAssert(testInstance.lock.replace == 1)
        XCTAssert(testInstance.lock.modify == 1)
        XCTAssert(testInstance.lock.destroy == 1)
    }

}
