import XCTest
import Vapor
import NIOCore
import Logging
import AsyncHTTPClient
import NIOEmbedded

final class ClientTests: XCTestCase {
    
    var remoteAppPort: Int!
    var remoteApp: Application!
    
    override func setUp() async throws {
        remoteApp = Application(.testing)
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
        
        remoteApp.environment.arguments = ["serve"]
        try remoteApp.boot()
        try remoteApp.start()
        
        XCTAssertNotNil(remoteApp.http.server.shared.localAddress)
        guard let localAddress = remoteApp.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(remoteApp.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        self.remoteAppPort = port
    }
    
    override func tearDown() async throws {
        remoteApp.shutdown()
    }
    
    func testClientConfigurationChange() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        try app.server.start(address: .hostname("localhost", port: 8080))
        defer { app.server.shutdown() }

        let res = try app.client.get("http://localhost:8080/redirect").wait()

        XCTAssertEqual(res.status, .seeOther)
    }
    
    func testClientConfigurationCantBeChangedAfterClientHasBeenUsed() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        try app.server.start(address: .hostname("localhost", port: 8080))
        defer { app.server.shutdown() }

        _ = try app.client.get("http://localhost:8080/redirect").wait()
        
        app.http.client.configuration.redirectConfiguration = .follow(max: 1, allowCycles: false)
        let res = try app.client.get("http://localhost:8080/redirect").wait()
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
    
    func testBoilerplateClient() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("foo") { req -> EventLoopFuture<String> in
            return req.client.get("http://localhost:\(self.remoteAppPort!)/status/201").map { res in
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
            XCTAssert(type(of: app.http.client.shared) == HTTPClient.self)
            finishLine.leave()
        }

        finishLine.enter()
        Thread.async {
            startingPistol.leave()
            startingPistol.wait()
            XCTAssert(type(of: app.http.client.shared) == HTTPClient.self)
            finishLine.leave()
        }

        finishLine.wait()
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
        print("We are testing client logging")
        let app = Application(.testing)
        defer { app.shutdown() }
        let logs = TestLogHandler()
        app.logger = logs.logger

        _ = try app.client.get("https://www.vapor.codes").wait()

        let metadata = logs.getMetadata()
        XCTAssertNotNil(metadata["ahc-request-id"])
    }
}

final class CustomClient: Client {
    var eventLoop: EventLoop {
        EmbeddedEventLoop()
    }
    var requests: [ClientRequest]

    init() {
        self.requests = []
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        self.requests.append(request)
        return self.eventLoop.makeSucceededFuture(ClientResponse())
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        self
    }
}

extension Application {
    struct CustomClientKey: StorageKey {
        typealias Value = CustomClient
    }

    var customClient: CustomClient {
        if let existing = self.storage[CustomClientKey.self] {
            return existing
        } else {
            let new = CustomClient()
            self.storage[CustomClientKey.self] = new
            return new
        }
    }
}

extension Application.Clients.Provider {
    static var custom: Self {
        .init {
            $0.clients.use { $0.customClient }
        }
    }
}


final class TestLogHandler: LogHandler {
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }

    @ThreadSafe
    var metadata: Logger.Metadata
    var logLevel: Logger.Level
    @ThreadSafe
    var messages: [Logger.Message]

    var logger: Logger {
        .init(label: "test") { label in
            self
        }
    }

    init() {
        self.metadata = [:]
        self.logLevel = .trace
        self.messages = []
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.messages.append(message)
    }

    func read() -> [String] {
        let copy = self.messages
        self.messages = []
        return copy.map { $0.description }
    }
    
    func getMetadata() -> Logger.Metadata {
        return self.metadata
    }
}


struct SomeJSON: Content {
    let vapor: SomeNestedJSON
    
    init() {
        vapor = SomeNestedJSON(name: "The Vapor Project", age: 7, repos: [
            VaporRepoJSON(name: "WebsocketKit", url: "https://github.com/vapor/websocket-kit"),
            VaporRepoJSON(name: "PostgresNIO", url: "https://github.com/vapor/postgres-nio")
        ])
    }
}

struct SomeNestedJSON: Content {
    let name: String
    let age: Int
    let repos: [VaporRepoJSON]
}

struct VaporRepoJSON: Content {
    let name: String
    let url: String
}

struct AnythingResponse: Content {
    var headers: [String: String]
    var json: [String: String]
}
