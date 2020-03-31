import Vapor
import XCTest

final class ClientTests: XCTestCase {
    func testClientConfigurationChange() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.clients.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        let server = try app.server.start(hostname: "localhost", port: 8080)
        defer { server.shutdown() }

        let res = try app.client.get("http://localhost:8080/redirect").wait()

        XCTAssertEqual(res.status, .seeOther)
    }
    
    func testClientConfigurationCantBeChangedAfterClientHasBeenUsed() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.clients.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        let server = try app.server.start(hostname: "localhost", port: 8080)
        defer { server.shutdown() }

        _ = try app.client.get("http://localhost:8080/redirect").wait()
        
        app.clients.configuration.redirectConfiguration = .follow(max: 1, allowCycles: false)
        let res = try app.client.get("http://localhost:8080/redirect").wait()
        XCTAssertEqual(res.status, .seeOther)
    }

    func testClientResponseCodable() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let res = try app.client.get("https://httpbin.org/json").wait()

        let encoded = try JSONEncoder().encode(res)
        let decoded = try JSONDecoder().decode(ClientResponse.self, from: encoded)
        
        XCTAssertEqual(res, decoded)
    }
    
    func testClientBeforeSend() throws {
        let app = Application()
        defer { app.shutdown() }
        try app.boot()
        
        let res = try app.client.post("http://httpbin.org/anything") { req in
            try req.content.encode(["hello": "world"])
        }.wait()

        struct HTTPBinAnything: Codable {
            var headers: [String: String]
            var json: [String: String]
        }
        let data = try res.content.decode(HTTPBinAnything.self)
        XCTAssertEqual(data.json, ["hello": "world"])
        XCTAssertEqual(data.headers["Content-Type"], "application/json; charset=utf-8")
    }
    
    func testBoilerplateClient() throws {
        let app = Application(.init(
            name: "xctest",
            arguments: ["vapor", "serve", "-b", "localhost:8080", "--log", "trace"]
        ))
        try LoggingSystem.bootstrap(from: &app.environment)
        defer { app.shutdown() }

        app.get("foo") { req -> EventLoopFuture<String> in
            return req.client.get("https://httpbin.org/status/201").map { res in
                XCTAssertEqual(res.status.code, 201)
                req.application.running?.stop()
                return "bar"
            }.flatMapErrorThrowing {
                req.application.running?.stop()
                throw $0
            }
        }

        try app.boot()
        try app.start()

        let res = try app.client.get("http://localhost:8080/foo").wait()
        XCTAssertEqual(res.body?.string, "bar")

        try app.running?.onStop.wait()
    }
    
    func testApplicationClientThreadSafety() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let startingPistol = DispatchGroup()
        startingPistol.enter()
        startingPistol.enter()

        let finishLine = DispatchGroup()
        finishLine.enter()
        Thread.async {
            startingPistol.leave()
            startingPistol.wait()
            XCTAssert(type(of: app.clients.http) == AsyncHTTPClient.self)
            finishLine.leave()
        }

        finishLine.enter()
        Thread.async {
            startingPistol.leave()
            startingPistol.wait()
            XCTAssert(type(of: app.clients.http) == AsyncHTTPClient.self)
            finishLine.leave()
        }

        finishLine.wait()
    }
}
