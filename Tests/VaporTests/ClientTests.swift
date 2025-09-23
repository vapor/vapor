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
    @Test("Test Client beforeSend()")
    func testClientBeforeSend() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                let res = try await app.client.post("http://localhost:\(remoteAppPort)/anything") { req in
                    try req.content.encode(["hello": "world"])
                }

                let data = try await res.content.decode(AnythingResponse.self)
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

                let data = try await res.content.decode(AnythingResponse.self)
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

    @Test("Test Boilerplate Client")
    func testBoilerplateClient() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

                app.get("foo") { req async throws -> String in
                    do {
                        let response = try await req.application.client.get("http://localhost:\(remoteAppPort)/status/201")
                        #expect(response.status.code == 201)
                        req.application.running?.stop()
                        return "bar"
                    } catch {
                        req.application.running?.stop()
                        throw error
                    }
                }

                try await withRunningApp(app: app) { port in
                    let res = try await app.client.get("http://localhost:\(port)/foo")
                    #expect(res.body?.string == "bar")
                }
            }
        }
    }

    @Test("Test Custom Client")
    func testCustomClient() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            let customClient = CustomClient()
            try await withApp(services: .init(client: .provided(customClient))) { app in
                _ = try await app.client.get("https://vapor.codes")

                #expect(customClient.requests.count == 1)
                #expect(customClient.requests.first?.url.host == "vapor.codes")
            }
        }
    }

    @Test("Test Client Content", .disabled("Broken in AHC"), .bug("https://github.com/swift-server/async-http-client/issues/854"))
    func testClientLogging() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            let logs = TestLogHandler()
            try await withApp(services: .init(logger: .provided(logs.logger))) { app in
                _ = try await app.client.get("http://localhost:\(remoteAppPort)/status/201")

                let metadata = logs.getMetadata()
                #expect(metadata["ahc-request-id"] != nil)
            }
        }
    }

    // MARK: - Helpers
    func withRemoteApp<T>(_ block: (Application, Int) async throws -> T) async throws -> T {
        let remoteApp = try await Application(.testing)
        remoteApp.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

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

            guard let json:[String:Any] = try await JSONSerialization.jsonObject(with: req.newBody.data!) as? [String:Any] else {
                throw Abort(.badRequest)
            }

            let jsonResponse = json.mapValues {
                return "\($0)"
            }

            return AnythingResponse(headers: headers, json: jsonResponse)
        }

        remoteApp.get("stalling") { _ in
            try await Task.sleep(for: .seconds(1))
            return SomeJSON()
        }

        do {
            let result = try await withRunningApp(app: remoteApp) { port in
                let result = try await block(remoteApp, port)
                return result
            }

            try await remoteApp.shutdown()
            return result
        } catch {
            try await remoteApp.shutdown()
            throw error
        }
    }
}

final class CustomClient: Client, Sendable {
    let _requests: NIOLockedValueBox<[ClientRequest]>
    let contentConfiguration: ContentConfiguration = .default()
    let byteBufferAllocator: ByteBufferAllocator = .init()
    var requests: [ClientRequest] {
        get {
            self._requests.withLockedValue { $0 }
        }
    }

    init(_requests: [ClientRequest] = []) {
        self._requests = .init(_requests)
    }

    func send(_ request: ClientRequest) async throws -> ClientResponse {
        self._requests.withLockedValue { $0.append(request) }
        return ClientResponse()
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
