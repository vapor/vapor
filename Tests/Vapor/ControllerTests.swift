import XCTest
import Engine
@testable import Vapor

extension Request {
    convenience init(method: HTTPMethod, path: String) {
        let uri = URI(scheme: "", userInfo: nil, host: "", port: nil, path: path, query: nil, fragment: nil)
        self.init(method: method, uri: uri)
    }
}

private class TestController: DropletInitializable, Resource {

    required init(droplet: Droplet) { }

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
        ("testControllerActionRouting_withDropletInitializable", testControllerActionRouting_withDropletInitializable),
        ("testControllerMethodsHit", testControllerMethodsHit)
    ]

    func testController() throws {
        let drop = Droplet()

        let instance = TestController(droplet: drop)
        drop.resource("foo", makeControllerWith: { return instance })

        let fooIndex = Request(method: .get, path: "foo")
        if let handler = drop.router.route(fooIndex) {
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
        let drop = Droplet()

        drop.add(.get, path: "/hello", action: TestActionController.hello) { TestActionController(person: "Tanner") }

        let request = Request(method: .get, path: "hello")
        guard let handler = drop.router.route(request) else {
            XCTFail("No handler found for TestActionController.hello")
            return
        }

        let _ = try handler.respond(to: request)
        XCTAssertEqual(TestActionController.helloRunCount, 1)
    }

    func testControllerActionRouting_withDefaultInitializable() throws {
        TestActionController.helloRunCount = 0
        let drop = Droplet()

        drop.add(.get, path: "/hello", action: TestActionController.hello)

        let request = Request(method: .get, path: "hello")
        guard let handler = drop.router.route(request) else {
            XCTFail("No handler found for TestActionController.hello")
            return
        }

        let _ = try handler.respond(to: request)
        XCTAssertEqual(TestActionController.helloRunCount, 1)
    }

    func testControllerActionRouting_withDropletInitializable() throws {
        TestActionController.helloRunCount = 0

        let drop = Droplet()

        drop.add(.get, path: "/hello", action: TestActionController.hello)

        let request = Request(method: .get, path: "hello")
        guard let handler = drop.router.route(request) else {
            XCTFail("No handler found for TestController.hello")
            return
        }

        let _ = try handler.respond(to: request)
        XCTAssertEqual(TestActionController.helloRunCount, 1)
    }


    func testControllerMethodsHit() throws {
        let drop = Droplet()
        // Need single instance to test
        let testInstance = TestController(droplet: drop)
        let factory: (Void) -> TestController = { print("blahblah : \(testInstance)"); return testInstance }
        drop.resource("/test", makeControllerWith: factory)

        func handleRequest(req: Request) throws {
            guard let handler = drop.router.route(req) else { return }
            let _ = try handler.respond(to: req)
        }

        let arrayRequests: [Request] = [.get, .post, .delete].map {
            return Request(method: $0, path: "/test", host: "0.0.0.0")
        }

        try arrayRequests.forEach(handleRequest)
        XCTAssert(testInstance.lock.index == 1)
        XCTAssert(testInstance.lock.store == 1)
        XCTAssert(testInstance.lock.destroyAll == 1)
        XCTAssert(testInstance.lock.show == 0)
        XCTAssert(testInstance.lock.replace == 0)
        XCTAssert(testInstance.lock.modify == 0)
        XCTAssert(testInstance.lock.destroy == 0)

        let individualRequests: [Request] = [.get, .post, .put, .patch, .delete].map {
            return Request(method: $0, path: "test/123", host: "0.0.0.0")
        }
        try individualRequests.forEach(handleRequest)

        XCTAssert(testInstance.lock.show == 1)
        XCTAssert(testInstance.lock.replace == 1)
        XCTAssert(testInstance.lock.modify == 1)
        XCTAssert(testInstance.lock.destroy == 1)
    }

}

extension Request {
    convenience init(method: HTTPMethod, path: String, host: String) {
        let uri = URI(scheme: "", userInfo: nil, host: host, port: nil, path: path, query: nil, fragment: nil)
        self.init(method: method, uri: uri)
    }
}
