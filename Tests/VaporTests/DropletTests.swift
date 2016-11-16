import XCTest
@testable import Vapor
import HTTP
import Core
import SocksCore

class DropletTests: XCTestCase {
    static let allTests = [
        ("testMediaType", testMediaType),
        ("testTLSConfig", testTLSConfig),
        ("testRunDefaults", testRunDefaults),
        ("testRunConfig", testRunConfig),
        ("testRunManual", testRunManual),
    ]

    func testData() {
        do {
            let file = try DataFile().load(path: #file)
            XCTAssert(file.string.contains("meta"))
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

        let drop = Droplet(workDir: workDir)

        drop.middleware = [
            FileMiddleware(publicDir: drop.workDir + "Public/")
        ]

        let request = Request(method: .get, path: "styles/app.css")

        guard let response = try? drop.respond(to: request) else {
            XCTFail("drop could not respond")
            return
        }

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
                "secure": [
                    "host": "vapor.codes",
                    "port": 443,
                    "securityLayer": "tls",
                    "tls": [
                        "certificates": "ca",
                        "signature": "selfSigned"
                    ]
                ]
            ]
        ])

        _ = Droplet(config: config)
    }

    func testRunDefaults() throws {
        let drop = Droplet(arguments: ["vapor", "serve"])

        drop.get("foo") { req in
            return "bar"
        }

        try drop.startServers()

        drop.console.wait(seconds: 2)
        
        let res = try! drop.client.get("http://0.0.0.0:8080/foo")
        XCTAssertEqual(try! res.bodyString(), "bar")
        
        drop.stopServers()

        XCTAssert(drop.startedServers.count == 0)

        drop.console.wait(seconds: 0.5)

        // TODO: Enable when a new version of vapor/engine is released with this PR:
        // https://github.com/vapor/engine/pull/78
        // Currently, listening sockets aren't closed properly, resulting in wrong errors

//        do {
//            _ = try drop.client.get("http://0.0.0.0:8080/foo")
//            XCTFail("Expected to throw")
//        } catch let error as SocksError {
//            guard case ErrorReason.connectFailed = error.type else {
//                XCTFail("Unexpected SocksError: \(error)")
//                return
//            }
//        }
    }

    func testRunConfig() throws {
        let config = Config([
            "servers": [
                "my-server": [
                    "host": "0.0.0.0",
                    "port": 8337,
                    "securityLayer": "none"
                ]
            ]
        ])
        let drop = Droplet(arguments: ["vapor", "serve"], config: config)

        drop.get("foo") { req in
            return "bar"
        }

        try drop.startServers()

        drop.console.wait(seconds: 2)

        let res = try drop.client.get("http://0.0.0.0:8337/foo")
        XCTAssertEqual(try res.bodyString(), "bar")
    }

    func testRunManual() throws {
        let drop = Droplet(arguments: ["vapor", "serve"])

        drop.get("foo") { req in
            return "bar"
        }

        _ = try drop.startServer(("0.0.0.0", 8424, .none), name: "my-server")

        drop.console.wait(seconds: 2)

        let res = try drop.client.get("http://0.0.0.0:8424/foo")
        XCTAssertEqual(try res.bodyString(), "bar")

        drop.stopServer(name: "my-server")
        
        XCTAssert(drop.startedServers.count == 0)
        
        drop.console.wait(seconds: 0.5)
        
        // TODO: Enable when a new version of vapor/engine is released with this PR:
        // https://github.com/vapor/engine/pull/78
        // Currently, listening sockets aren't closed properly, resulting in wrong errors
        
//        do {
//            _ = try drop.client.get("http://0.0.0.0:8424/foo")
//            XCTFail("Expected to throw")
//        } catch let error as SocksError {
//            guard case ErrorReason.connectFailed = error.type else {
//                XCTFail("Unexpected SocksError: \(error)")
//                return
//            }
//        }
    }
}
