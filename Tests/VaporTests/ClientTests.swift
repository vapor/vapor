import Vapor
import NIOConcurrencyHelpers
import NIOCore
import Logging
import NIOEmbedded
import Testing
import VaporTesting
import Foundation
import AsyncHTTPClient

@Suite("Client Tests")
struct ClientTests {
    @Test("Test changing the client configuration")
    func clientConfigurationChange() async throws {
        try await withApp { app in
            app.http.client.configuration.redirectConfiguration = .disallow

            app.get("redirect") {
                $0.redirect(to: "foo")
            }

            try await app.server.start(address: .hostname("localhost", port: 0))

            let port = try #require(app.http.server.shared.localAddress?.port, "Failed to get port")
            let res = try await app.client.get("http://localhost:\(port)/redirect")

            #expect(res.status == .seeOther)

            try await app.server.shutdown()
        }
    }

    @Test("Test that the client config can be changed after the client has already been used")
    func clientConfigurationCantBeChangedAfterClientHasBeenUsed() async throws {
        try await withApp { app in
            app.http.client.configuration.redirectConfiguration = .disallow

            app.get("redirect") {
                $0.redirect(to: "foo")
            }

            try await app.server.start(address: .hostname("localhost", port: 0))

            let port = try #require(app.http.server.shared.localAddress?.port, "Failed to get port")
            _ = try await app.client.get("http://localhost:\(port)/redirect")

            app.http.client.configuration.redirectConfiguration = .follow(max: 1, allowCycles: false)
            let res = try await app.client.get("http://localhost:\(port)/redirect")
            #expect(res.status == .seeOther)

            try await app.server.shutdown()
        }
    }

    @Test("TestClient Response Codable")
    func testClientResponseCodable() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                let res = try await app.client.get("http://localhost:\(remoteAppPort)/json")

                let encoded = try JSONEncoder().encode(res)
                let decoded = try JSONDecoder().decode(ClientResponse.self, from: encoded)

                #expect(res == decoded)
            }
        }
    }

    @Test("Test Client beforeSend()")
    func testClientBeforeSend() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                let res = try await app.client.post("http://localhost:\(remoteAppPort)/anything") { req in
                    try req.content.encode(["hello": "world"])
                }

                let data = try res.content.decode(AnythingResponse.self)
                #expect(data.json == ["hello": "world"])
                #expect(data.headers["content-type"] == "application/json; charset=utf-8")
            }
        }
    }

    @Test("Test Client Content")
    func testClientContent() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                let res = try await app.client.post("http://localhost:\(remoteAppPort)/anything", content: ["hello": "world"])

                let data = try res.content.decode(AnythingResponse.self)
                #expect(data.json == ["hello": "world"])
                #expect(data.headers["content-type"] == "application/json; charset=utf-8")
            }
        }
    }

    @Test("Test Client Tiemout")
    func testClientTimeout() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                await #expect(throws: Never.self, performing: {
                    try await app.client.get("http://localhost:\(remoteAppPort)/json") { $0.timeout = .seconds(1) }
                })
                await #expect(throws: HTTPClientError.deadlineExceeded) {
                    try await app.client.get("http://localhost:\(remoteAppPort)/stalling") {
                        $0.timeout = .milliseconds(200)
                    }
                }
            }
        }
    }

    @Test("Test Boilerplate Content")
    func testBoilerplateClient() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                app.http.server.configuration.port = 0

                app.get("foo") { req async throws -> String in
                    do {
                        let response = try await req.client.get("http://localhost:\(remoteAppPort)/status/201")
                        #expect(response.status.code == 201)
                        req.application.running?.stop()
                        return "bar"
                    } catch {
                        req.application.running?.stop()
                        throw error
                    }
                }

                app.environment.arguments = ["serve"]
                try await app.boot()
                try await app.startup()

                let port = try #require(app.http.server.shared.localAddress?.port)
                let res = try await app.client.get("http://localhost:\(port)/foo")
                #expect(res.body?.string == "bar")

                try await app.running?.onStop.get()
            }
        }
    }

    @Test("Test Custom Client")
    func testCustomClient() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                app.clients.use(.custom)
                _ = try await app.client.get("https://vapor.codes")

                #expect(app.customClient.requests.count == 1)
                #expect(app.customClient.requests.first?.url.host == "vapor.codes")
            }
        }
    }

    @Test("Test Client Content")
    func testClientLogging() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                let logs = TestLogHandler()
                app.logger = logs.logger

                _ = try await app.client.get("http://localhost:\(remoteAppPort)/status/201")

                let metadata = logs.getMetadata()
                #expect(metadata["ahc-request-id"] != nil)
            }
        }
    }

    // MARK: - Helpers
    func withRemoteApp<T>(_ block: (Application, Int) async throws -> T) async throws -> T {
        let remoteApp = try await Application(.testing)
        remoteApp.http.server.configuration.port = 0

        remoteApp.get("json") { _ in
            SomeJSON()
        }

        remoteApp.get("status", ":status") { req -> HTTPStatus in
            let status = try req.parameters.require("status", as: Int.self)
            return HTTPStatus(code: status)
        }

        remoteApp.post("anything") { req -> AnythingResponse in
            let headers = req.headers.reduce(into: [String: String]()) {
                $0[$1.name.canonicalName] = $1.value
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
            try await $0.eventLoop.scheduleTask(in: .seconds(1)) { SomeJSON() }.futureResult.get()
        }

        remoteApp.environment.arguments = ["serve"]
        try await remoteApp.boot()
        try await remoteApp.startup()

        let remotePort = try #require(remoteApp.http.server.shared.localAddress?.port, "Failed to get port")

        let result: T
        do {
            result = try await block(remoteApp, remotePort)
        } catch {
            try? await remoteApp.shutdown()
            throw error
        }
        try await remoteApp.shutdown()
        return result
    }
}

final class CustomClient: Client, Sendable {
    let eventLoop: any EventLoop
    let _requests: NIOLockedValueBox<[ClientRequest]>
    let contentConfiguration: ContentConfiguration = .default()
    let byteBufferAllocator: ByteBufferAllocator = .init()
    var requests: [ClientRequest] {
        get {
            self._requests.withLockedValue { $0 }
        }
    }

    init(eventLoop: any EventLoop, _requests: [ClientRequest] = []) {
        self.eventLoop = eventLoop
        self._requests = .init(_requests)
    }

    func send(_ request: ClientRequest) async throws -> ClientResponse {
        self._requests.withLockedValue { $0.append(request) }
        return ClientResponse()
    }

    func delegating(to eventLoop: any EventLoop) -> any Client {
        self
    }

    func logging(to logger: Logger) -> any Client {
        self
    }

    func allocating(to byteBufferAllocator: ByteBufferAllocator) -> any Client {
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
            let new = CustomClient(eventLoop: self.eventLoopGroup.any())
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

    var metadata: Logger.Metadata {
        get {
            self._metadata.withLockedValue { $0 }
        }
        set {
            self._metadata.withLockedValue { $0 = newValue }
        }
    }
    
    var logLevel: Logger.Level {
        get {
            _logLevel
        }
        set {
            // We don't use this anywhere
        }
    }
    
    var messages: [Logger.Message] {
        get {
            self._messages.withLockedValue { $0 }
        }
        set {
            self._messages.withLockedValue { $0 = newValue }
        }
    }
    
    let _logLevel: Logger.Level
    let _metadata: NIOLockedValueBox<Logger.Metadata>
    let _messages: NIOLockedValueBox<[Logger.Message]>

    var logger: Logger {
        .init(label: "test") { label in
            self
        }
    }

    init() {
        self._metadata = .init([:])
        self._logLevel = .trace
        self._messages = .init([])
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
        self._messages.withLockedValue { $0.append(message) }
    }

    func read() -> [String] {
        self._messages.withLockedValue {
            let copy = $0
            $0 = []
            return copy.map(\.description)
        }
    }

    func getMetadata() -> Logger.Metadata {
        self._metadata.withLockedValue { $0 }
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
