import XCTest
@testable import Vapor
import HTTP
import Core
import Sockets
import Dispatch
import Testing

class DropletTests: XCTestCase {
    static let allTests = [
        ("testData", testData),
        ("testMediaType", testMediaType),
        ("testTLSConfig", testTLSConfig),
        ("testRunDefaults", testRunDefaults),
        ("testRunConfig", testRunConfig),
        ("testHeadRequest", testHeadRequest),
        ("testDumpConfig", testDumpConfig),
        ("testProxy", testProxy),
        ("testDropletProxy", testDropletProxy),
        ("testWebsockets", testWebsockets),
        ("test404", test404),
        ("testErrorMiddleware404", testErrorMiddleware404),
        // ("testWebsocketsTLS", testWebsocketsTLS)
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
        #if swift(>=4.0)
        let parent = #file.split(separator: "/").map(String.init).dropLast(3).joined(separator: "/")
        #else
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast(3).joined(separator: "/")
        #endif
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
    
    func testProxy() throws {
        // FIXME: find a reliable proxy server
        /*
        let proxy = Proxy(
            hostname: "52.213.26.87",
            port: 8888,
            securityLayer: .none
        )
        let client = try EngineClient(
            hostname: "34.248.148.23",
            port: 80,
            securityLayer: .none,
            proxy: proxy
        )

        let req = Request(method: .get, path: "/")
        let res = try client.respond(to: req)
        try XCTAssertEqual(res.bodyString(), "It works!!!\n")
        */
    }
    
    func testDropletProxy() throws {
        // FIXME: find a reliable proxy server
        /*
        var config = Config([:])
        try config.set("droplet.client", "engine")
        try config.set("client.proxy.hostname", "52.213.26.87")
        try config.set("client.proxy.port", 8888)
        try config.set("client.proxy.securityLayer", "none")
        
        let drop = try Droplet(config)
        
        let res = try drop.client.get("http://34.248.148.23")
        try XCTAssertEqual(res.bodyString(), "It works!!!\n")
        */
    }
    
    func testWebsockets() throws {
        let drop = try Droplet()
        
        let group = DispatchGroup()
        group.enter()
        background {
            do {
                try drop.client.socket.connect(to: "ws://echo.websocket.org") { ws in
                    ws.onText = { ws, text in
                        XCTAssertEqual(text, "foo")
                        group.leave()
                    }
                    
                    try ws.send("foo")
                }
            } catch {
                XCTFail("\(error)")
            }
        }
        group.wait()
    }
    
    func testWebsocketsTLS() throws {
        let drop = try Droplet()
        
        let group = DispatchGroup()
        group.enter()
        background {
            do {
                try drop.client.socket.connect(to: "wss://echo.websocket.org") { ws in
                    ws.onText = { ws, text in
                        XCTAssertEqual(text, "foo")
                        group.leave()
                        
                    }
                    
                    try ws.send("foo")
                }
            } catch {
                XCTFail("\(error)")
                group.leave()
            }
        }
        group.wait()
    }
    
    func test404() throws {
        Testing.onFail = XCTFail
        let drop = try Droplet()
        
        try drop.testResponse(to: .get, at: "asdf", headers: [.accept: "text/html"])
            .assertStatus(is: .notFound)
    }

    func testErrorMiddleware404() throws {
        Testing.onFail = XCTFail

        let config = Config([:])
        let drop = try Droplet(middleware: [ErrorMiddleware(config: config)])

        try drop.testResponse(to: .get, at: "asdf", headers: [.accept: "text/html"])
            .assertStatus(is: .notFound)
    }

    // temporary fix for Circle CI
    #if Xcode
    
        func testFoundationClient() throws {
            var config = Config([:])
            try config.set("droplet.client", "foundation")
            let drop = try Droplet(config)
            let res = try! drop.client.get("https://httpbin.org/get")
            try print(res.bodyString())
            #if os(Linux)
                try XCTAssert(res.bodyString().contains("curl"))
            #else
                try XCTAssert(res.bodyString().contains("CFNetwork"))
            #endif
        }
    #endif
}
