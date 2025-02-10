#if !canImport(Darwin)
#if compiler(>=6.0)
import Dispatch
#else
@preconcurrency import Dispatch
#endif
#endif
import Foundation
import XCTest
import Vapor
import NIOCore
import Logging
import AsyncHTTPClient
import NIOEmbedded
import NIOConcurrencyHelpers

@available(*, deprecated, message: "Testing deprecated future APIs")
final class ClientTests: XCTestCase {
    var remoteAppPort: Int!
    var remoteApp: Application!
    
    override func setUp() async throws {
        remoteApp = try await Application.make(.testing)
        remoteApp.http.server.configuration.port = 0
        
        remoteApp.get("json") { _ in
            SomeJSON()
        }
        
        remoteApp.get("status", ":status") { req -> HTTPStatus in
            let status = try req.parameters.require("status", as: Int.self)
            return HTTPStatus(statusCode: status)
        }
        
        remoteApp.post("anything") { req -> AnythingResponse in
            let headers = req.headers.reduce(into: [String: String]()) {
                $0[$1.0] = $1.1
            }
            
            guard let json:[String:Any] = try JSONSerialization.jsonObject(with: req.body.data!) as? [String:Any] else {
                throw Abort(.badRequest)
            }
            
            let jsonResponse = json.mapValues {
                return "\($0)"
            }
            
            return AnythingResponse(headers: headers, json: jsonResponse)
        }

        remoteApp.get("stalling") {
            $0.eventLoop.scheduleTask(in: .seconds(2)) { SomeJSON() }.futureResult
        }
        
        remoteApp.environment.arguments = ["serve"]
        try await remoteApp.asyncBoot()
        try await remoteApp.startup()
        
        XCTAssertNotNil(remoteApp.http.server.shared.localAddress)
        guard let localAddress = remoteApp.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(remoteApp.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        self.remoteAppPort = port
    }
    
    override func tearDown() async throws {
        try await remoteApp.asyncShutdown()
    }
    
    func testClientConfigurationChange() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        try app.server.start(address: .hostname("localhost", port: 0))
        defer { app.server.shutdown() }
        
        guard let port = app.http.server.shared.localAddress?.port else {
            XCTFail("Failed to get port for app")
            return
        }

        let res = try app.client.get("http://localhost:\(port)/redirect").wait()

        XCTAssertEqual(res.status, .seeOther)
    }
    
    func testClientConfigurationCantBeChangedAfterClientHasBeenUsed() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        try app.server.start(address: .hostname("localhost", port: 0))
        defer { app.server.shutdown() }
        
        guard let port = app.http.server.shared.localAddress?.port else {
            XCTFail("Failed to get port for app")
            return
        }

        _ = try app.client.get("http://localhost:\(port)/redirect").wait()
        
        app.http.client.configuration.redirectConfiguration = .follow(max: 1, allowCycles: false)
        let res = try app.client.get("http://localhost:\(port)/redirect").wait()
        XCTAssertEqual(res.status, .seeOther)
    }

    func testClientResponseCodable() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let res = try app.client.get("http://localhost:\(remoteAppPort!)/json").wait()

        let encoded = try JSONEncoder().encode(res)
        let decoded = try JSONDecoder().decode(ClientResponse.self, from: encoded)
        
        XCTAssertEqual(res, decoded)
    }
    
    func testClientBeforeSend() throws {
        let app = Application()
        defer { app.shutdown() }
        try app.boot()
        
        let res = try app.client.post("http://localhost:\(remoteAppPort!)/anything") { req in
            try req.content.encode(["hello": "world"])
        }.wait()

        let data = try res.content.decode(AnythingResponse.self)
        XCTAssertEqual(data.json, ["hello": "world"])
        XCTAssertEqual(data.headers["content-type"], "application/json; charset=utf-8")
    }
    
    func testClientContent() throws {
        let app = Application()
        defer { app.shutdown() }
        try app.boot()
        
        let res = try app.client.post("http://localhost:\(remoteAppPort!)/anything", content: ["hello": "world"]).wait()

        let data = try res.content.decode(AnythingResponse.self)
        XCTAssertEqual(data.json, ["hello": "world"])
        XCTAssertEqual(data.headers["content-type"], "application/json; charset=utf-8")
    }

    func testClientTimeout() throws {
        let app = Application()
        defer { app.shutdown() }
        try app.boot()

        XCTAssertNoThrow(try app.client.get("http://localhost:\(remoteAppPort!)/json") { $0.timeout = .seconds(1) }.wait())
        XCTAssertThrowsError(try app.client.get("http://localhost:\(remoteAppPort!)/stalling") { $0.timeout = .seconds(1) }.wait()) {
            XCTAssertTrue(type(of: $0) == HTTPClientError.self, "\(type(of: $0)) is not a \(HTTPClientError.self)")
            XCTAssertEqual($0 as? HTTPClientError, .deadlineExceeded)
        }
    }
    
    func testBoilerplateClient() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let remotePort = self.remoteAppPort!

        app.get("foo") { req -> EventLoopFuture<String> in
            return req.client.get("http://localhost:\(remotePort)/status/201").map { res in
                XCTAssertEqual(res.status.code, 201)
                req.application.running?.stop()
                return "bar"
            }.flatMapErrorThrowing {
                req.application.running?.stop()
                throw $0
            }
        }

        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try app.boot()
        try app.start()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let res = try app.client.get("http://localhost:\(port)/foo").wait()
        XCTAssertEqual(res.body?.string, "bar")

        try app.running?.onStop.wait()
    }

    func testCustomClient() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.clients.use(.custom)
        _ = try app.client.get("https://vapor.codes").wait()

        XCTAssertEqual(app.customClient.requests.count, 1)
        XCTAssertEqual(app.customClient.requests.first?.url.host, "vapor.codes")
    }

    func testClientLogging() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let logs = TestLogHandler()
        app.logger = logs.logger

        _ = try app.client.get("http://localhost:\(remoteAppPort!)/status/201").wait()

        let metadata = logs.getMetadata()
        XCTAssertNotNil(metadata["ahc-request-id"])
    }
}
