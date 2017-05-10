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
        ("testHeadRequest", testHeadRequest)
    ]

    func testData() {
        do {
            let file = try DataFile.read(at: #file)
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

        let config = try Config(node: [
            "droplet": ["workDir": workDir]
        ])
        let drop = try Droplet(config)

        let request = Request(method: .get, path: "styles/app.css")

        let response = try drop.respond(to: request)

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

        _ = try Droplet(config)
    }

    func testRunDefaults() throws {
        let config = Config([:])
        config.arguments = ["vapor", "serve", "--port=8523"]
        let drop = try Droplet(config)

        drop.get("foo") { req in
            return "bar"
        }
        
        XCTAssertEqual(try drop.config.makeServerConfig().port, 8523)
    }

    func testRunConfig() throws {
        let config = Config([
            "server": [
                "hostname": "0.0.0.0",
                "port": 8524,
                "securityLayer": "none"
            ]
        ])
        XCTAssertEqual(try config.makeServerConfig().port, 8524)
    }

    func testHeadRequest() throws {
        let drop = try Droplet()
        drop.get("foo") { req in
            return "Hi, I'm a body"
        }

        let getResp = try drop.request(.get, "http://0.0.0.0:9222/foo")
        XCTAssertEqual(try getResp.bodyString(), "Hi, I'm a body")

        let head = Request(method: .head, uri: "http://0.0.0.0:9222/foo")
        let headResp = try drop.respond(to: head)
        XCTAssertEqual(try headResp.bodyString(), "")
    }
    
    func testDumpConfig() throws {
        let config = Config([
            "server": [
                "hostname": "0.0.0.0",
                "port": 8524,
                "securityLayer": "none"
            ]
        ])
        config.arguments = ["vapor", "dump-config", "server.port"]
        let drop = try Droplet(config)
        try drop.runCommands()
    }
}
