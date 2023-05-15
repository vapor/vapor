import Vapor
import XCTest
import XCTVapor
import NIOConcurrencyHelpers
import NIOCore
import Logging
import NIOEmbedded

final class AsyncClientTests: XCTestCase {
    func testClientConfigurationChange() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        try app.server.start(address: .hostname("localhost", port: 8080))
        defer { app.server.shutdown() }

        let res = try await app.client.get("http://localhost:8080/redirect")

        XCTAssertEqual(res.status, .seeOther)
    }

    func testClientConfigurationCantBeChangedAfterClientHasBeenUsed() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        try app.server.start(address: .hostname("localhost", port: 8080))
        defer { app.server.shutdown() }

        _ = try await app.client.get("http://localhost:8080/redirect")

        app.http.client.configuration.redirectConfiguration = .follow(max: 1, allowCycles: false)
        let res = try await app.client.get("http://localhost:8080/redirect")
        XCTAssertEqual(res.status, .seeOther)
    }

    func testClientResponseCodable() async throws {
        let remoteApp = Application(.testing)
        remoteApp.http.server.configuration.port = 0
        defer { remoteApp.shutdown() }
        
        remoteApp.get("json") { _ in
            SomeJSON()
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
        
        let app = Application(.testing)
        defer { app.shutdown() }

        let res = try await app.client.get("http://localhost:\(port)/json")

        let encoded = try JSONEncoder().encode(res)
        let decoded = try JSONDecoder().decode(ClientResponse.self, from: encoded)

        XCTAssertEqual(res, decoded)
    }

    func testClientBeforeSend() async throws {
        let remoteApp = Application(.testing)
        remoteApp.http.server.configuration.port = 0
        defer { remoteApp.shutdown() }
        
        struct AnythingResponse: Content {
            var headers: [String: String]
            var json: [String: String]
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
        guard let remoteAppLocalAddress = remoteApp.http.server.shared.localAddress,
              let remoteAppPort = remoteAppLocalAddress.port else {
            XCTFail("couldn't get ip/port from \(remoteApp.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let app = Application()
        defer { app.shutdown() }
        try app.boot()

        let res = try await app.client.post("http://localhost:\(remoteAppPort)/anything") { req in
            try req.content.encode(["hello": "world"])
        }

        let data = try res.content.decode(AnythingResponse.self)
        XCTAssertEqual(data.json, ["hello": "world"])
        XCTAssertEqual(data.headers["content-type"], "application/json; charset=utf-8")
    }

    func testBoilerplateClient() async throws {
        let remoteApp = Application(.testing)
        remoteApp.http.server.configuration.port = 0
        defer { remoteApp.shutdown() }
        
        remoteApp.get("status", "201") { _ in
            return HTTPStatus.created
        }
        
        remoteApp.environment.arguments = ["serve"]
        try remoteApp.boot()
        try remoteApp.start()
        
        XCTAssertNotNil(remoteApp.http.server.shared.localAddress)
        guard let remoteAppLocalAddress = remoteApp.http.server.shared.localAddress,
              let remoteAppPort = remoteAppLocalAddress.port else {
            XCTFail("couldn't get ip/port from \(remoteApp.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let app = Application(.testing)
        app.http.server.configuration.port = 0
        defer { app.shutdown() }

        app.get("foo") { req async throws -> String in
            do {
                let response = try await req.client.get("http://localhost:\(remoteAppPort)/status/201")
                XCTAssertEqual(response.status.code, 201)
                req.application.running?.stop()
                return "bar"
            } catch {
                req.application.running?.stop()
                throw error
            }
        }

        app.environment.arguments = ["serve"]
        try app.boot()
        try app.start()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let res = try await app.client.get("http://localhost:\(port)/foo")
        XCTAssertEqual(res.body?.string, "bar")

        try await app.running?.onStop.get()
    }

    func testCustomClient() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.clients.use(.custom)
        _ = try await app.client.get("https://vapor.codes")

        XCTAssertEqual(app.customClient.requests.count, 1)
        XCTAssertEqual(app.customClient.requests.first?.url.host, "vapor.codes")
    }

    func testClientLogging() async throws {
        let remoteApp = Application(.testing)
        remoteApp.http.server.configuration.port = 0
        defer { remoteApp.shutdown() }
        
        remoteApp.get("status", "201") { _ in
            return HTTPStatus.created
        }
        
        remoteApp.environment.arguments = ["serve"]
        try remoteApp.boot()
        try remoteApp.start()
        
        XCTAssertNotNil(remoteApp.http.server.shared.localAddress)
        guard let remoteAppLocalAddress = remoteApp.http.server.shared.localAddress,
              let remoteAppPort = remoteAppLocalAddress.port else {
            XCTFail("couldn't get ip/port from \(remoteApp.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        print("We are testing client logging")
        let app = Application(.testing)
        defer { app.shutdown() }
        let logs = TestLogHandler()
        app.logger = logs.logger

        _ = try await app.client.get("http://localhost:\(remoteAppPort)/status/201")

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
        get { self.lock.withLock { self.metadata[key] } }
        set { self.lock.withLockVoid { self.metadata[key] = newValue } }
    }

    let lock: NIOLock
    var metadata: Logger.Metadata
    var logLevel: Logger.Level
    var messages: [Logger.Message]

    var logger: Logger {
        .init(label: "test") { label in
            self
        }
    }

    init() {
        self.lock = .init()
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
        self.lock.withLockVoid {
            self.messages.append(message)
        }
    }

    func read() -> [String] {
        self.lock.withLock { () -> [Logger.Message] in
            let copy = self.messages
            self.messages = []
            return copy
        }.map(\.description)
    }

    func getMetadata() -> Logger.Metadata {
        self.lock.withLock { () -> Logger.Metadata in
            let copy = self.metadata
            return copy
        }
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
