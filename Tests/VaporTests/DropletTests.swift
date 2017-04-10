import XCTest
@testable import Vapor
import HTTP
import Core
import Sockets

class DropletTests: XCTestCase {
    static let allTests = [
        ("testData", testData),
        ("testMediaType", testMediaType),
        ("testTLSConfig", testTLSConfig),
        ("testRunDefaults", testRunDefaults),
        ("testRunConfig", testRunConfig),
        ("testRunManual", testRunManual),
        ("testHeadRequest", testHeadRequest),
        ("testMiddlewareOrder", testMiddlewareOrder),
    ]

    func testData() {
        do {
            let file = try DataFile().load(path: #file)
            XCTAssert(file.makeString().contains("meta"))
        } catch {
            print("File load failed: \(error)")
        }
    }

    /**
        Ensures requests to files like CSS
        files have appropriate "Content-Type"
        headers returned.
    */
    func testMediaType() throws {
        // drop /Tests/VaporTests/DropletTests.swift to reach top level directory
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast(3).joined(separator: "/")
        let workDir = "/\(parent)/Sources/Development/"

        let drop = try Droplet(workDir: workDir)

        drop.middleware = [
            FileMiddleware(publicDir: drop.workDir + "Public/")
        ]

        let request = Request(method: .get, path: "styles/app.css")

        let response = drop.respond(to: request)

        var found = false
        for header in response.headers {
            guard header.key == "Content-Type" else { continue }
            guard header.value == "text/css" else { continue }
            found = true
        }

        XCTAssert(found, "CSS Content Type not found: \(response)")
    }

    func testTLSConfig() throws {
        let config = Config([
            "servers": [
                "hostname": "vapor.codes",
                "port": 443,
                "securityLayer": "tls",
                "tls": [
                    "certificates": "ca",
                    "signature": "selfSigned"
                ]
            ]
        ])

        _ = try Droplet(config: config)
    }

    func testRunDefaults() throws {
        let drop = try Droplet(arguments: ["vapor", "serve", "--port=8523"])

        drop.get("foo") { req in
            return "bar"
        }

        background {
            try! drop.run()
        }

        drop.console.wait(seconds: 1)

        let res = try drop.client.request(.get, "http://0.0.0.0:8523/foo")
        XCTAssertEqual(try res.bodyString(), "bar")
    }

    func testRunConfig() throws {
        let config = Config([
            "server": [
                "hostname": "0.0.0.0",
                "port": 8524,
                "securityLayer": "none"
            ]
        ])
        let drop = try Droplet(arguments: ["vapor", "serve"], config: config)

        drop.get("foo") { req in
            return "bar"
        }

        background {
            print("before run")
            try! drop.run()
        }
        
        print("before wait")
        drop.console.wait(seconds: 2)
        print("after wait")

        print("before request")
        let res = try drop.client.request(.get, "http://0.0.0.0:8524/foo")
        print("before assert")
        XCTAssertEqual(try res.bodyString(), "bar")
        print("done")
    }

    func testRunManual() throws {
        let drop = try Droplet(arguments: ["vapor", "serve"])

        drop.get("foo") { req in
            return "bar"
        }

        background {
            let config = ServerConfig(port: 8424)
            try! drop.serve(config)
        }

        drop.console.wait(seconds: 1)
        let res = try drop.client.request(.get, "http://0.0.0.0:8424/foo")
        XCTAssertEqual(try res.bodyString(), "bar")
    }

    func testHeadRequest() throws {
        let drop = try Droplet(arguments: ["vapor", "serve"])
        drop.get("foo") { req in
            return "Hi, I'm a body"
        }

        background {
            let config = ServerConfig(port: 9222)
            try! drop.serve(config)
        }

        drop.console.wait(seconds: 1)

        let getResp = try drop.client.request(.get, "http://0.0.0.0:9222/foo")
        XCTAssertEqual(try getResp.bodyString(), "Hi, I'm a body")

        let head = try Request(method: .head, uri: "http://0.0.0.0:9222/foo")
        let headResp = try drop.client.respond(to: head)
        XCTAssertEqual(try headResp.bodyString(), "")
    }

    func testMiddlewareOrder() throws {
        struct Mid: Middleware {
            let handler: () -> Void

            func respond(to request: Request, chainingTo next: Responder) throws -> Response {
                handler()
                return try next.respond(to: request)
            }
        }

        var middleware: [String] = []

        let drop = try Droplet()
        drop.middleware = [
            Mid(handler: { middleware.append("one") }),
            Mid(handler: { middleware.append("two") })
        ]

        drop.get { req in return "foo" }

        let req = Request(method: .get, path: "")
        let response = drop.respond(to: req)
        XCTAssertEqual(try response.bodyString(), "foo")

        XCTAssertEqual(middleware, ["one", "two"])
    }
    
    func testDumpConfig() throws {
        let config = Config([
            "server": [
                "hostname": "0.0.0.0",
                "port": 8524,
                "securityLayer": "none"
            ]
        ])
        let drop = try Droplet(arguments: ["vapor", "dump-config", "server.port"], config: config)
        background {
            try! drop.run()
        }
        drop.console.wait(seconds: 1)
    }
}
