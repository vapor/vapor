import Vapor
import XCTest
import HTTP
import Service

class MiddlewareTests: XCTestCase {
    func testConfigDate() throws {
        var config = Config()
        try config.set("droplet", "middleware", to: ["date"])

        let drop = try Droplet(config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["Date"] != nil)
    }

    func testConfigDateMissing() throws {
        var config = Config()
        try config.set("droplet", "middleware", to: ["error"])

        let drop = try Droplet(config)
        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["Date"] == nil)
    }

    func testConfigDateProvided() throws {
        var config = Config()
        try config.set("droplet", "middleware", to: ["foo"])

        var services = Services.default()
        services.register(FooMiddleware(), name: "foo", supports: [Middleware.self])
        
        let drop = try Droplet(config, services)

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testMultiple() throws {
        var config = Config()
        try config.set("droplet", "middleware", to: ["foo", "my-date"])

        var services = Services.default()
        services.register(FooMiddleware(), name: "foo", supports: [Middleware.self])
        services.register(DateMiddleware(), name: "my-date", supports: [Middleware.self])
        
        let drop = try Droplet(config, services)

        drop.get { _ in
            return "Hello, world"
        }

        let req = Request(method: .get, path: "/")
        let res = try drop.respond(to: req)

        XCTAssert(res.headers["bar"] != nil)
        XCTAssert(res.headers["date"] != nil)
    }

    func testConfigClient() throws {
        let foo = FooMiddleware()

        let res = try EngineClient.factory.get("http://httpbin.org/headers", through: [foo])

        // test to make sure basic server saw the
        // header the middleware added
        XCTAssert(try res.bodyString().contains("Foo") == true)
        XCTAssert(try res.bodyString().contains("bar") == true)

        // test to make sure the middleware
        // added headers to the response
        XCTAssertEqual(res.headers["bar"], "baz")
    }

    func testConfigClientNotEnabled() throws {
        var config = Config()
        try config.set("droplet", "client", to: "engine")
        
        var services = Services.default()
        services.register(FooMiddleware(), name: "foo", supports: [Middleware.self])
        
        let drop = try! Droplet(config, services)

        let res = try! drop.client().request(.get, "http://httpbin.org/headers")

        XCTAssert(try res.bodyString().contains("Foo") != true)
        XCTAssert(try res.bodyString().contains("bar") != true)
        XCTAssertNil(res.headers["bar"])
    }
    
    static let allTests = [
        ("testConfigDate", testConfigDate),
        ("testConfigDateMissing", testConfigDateMissing),
        ("testConfigDateProvided", testConfigDateProvided),
        ("testMultiple", testMultiple),
        ("testConfigClient", testConfigClient),
        ("testConfigClientNotEnabled", testConfigClientNotEnabled),
    ]
}

class FooMiddleware: Middleware {
    init() {}
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        request.headers["foo"] = "bar"
        let response = try next.respond(to: request)
        response.headers["bar"] = "baz"
        return response
    }
}
