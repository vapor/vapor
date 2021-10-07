import Vapor
import XCTest

final class ClientTests: XCTestCase {
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
        let app = Application(.testing)
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

        app.environment.arguments = ["serve"]
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

        _ = try app.client.get("https://httpbin.org/json").wait()

        let metadata = logs.getMetadata()
        XCTAssertNotNil(metadata["ahc-request-id"])
    }
}

private final class CustomClient: Client {
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

private extension Application {
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

private extension Application.Clients.Provider {
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
