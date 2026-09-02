import Vapor
import NIOConcurrencyHelpers
import NIOCore
import NIOFoundationEssentialsCompat
import Logging
import NIOEmbedded
import Testing
import VaporTesting
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AsyncHTTPClient
import HTTPTypes
import RoutingKit
import InMemoryLogging

@Suite("Client Tests")
struct ClientTests {
    #if HTTPClient
    @Test("Test Client beforeSend()")
    func testClientBeforeSend() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                let res = try await app.client.post("http://127.0.0.1:\(remoteAppPort)/anything") { req in
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
                let res = try await app.client.post("http://127.0.0.1:\(remoteAppPort)/anything", content: ["hello": "world"])

                let data = try await res.content.decode(AnythingResponse.self)
                #expect(data.json == ["hello": "world"])
                #expect(data.headers["content-type"] == "application/json; charset=utf-8")
            }
        }
    }

    @Test("Test Client Timeout")
    func testClientTimeout() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            try await withApp { app in
                // A request to loopback that should succeed in milliseconds. Addressed by IP
                // rather than `localhost`: the remote app binds IPv4 only, and `localhost`
                // resolves to `::1` first, so a name here means every request starts with a
                // doomed IPv6 attempt whose cost depends on whether the host refuses it or
                // black-holes it.
                // The budget here is not the thing under test — that a request carrying a
                // timeout still completes is. It is set far above any plausible loopback
                // round trip because a tight one measures how busy the machine is instead:
                // at two seconds this failed in 4 of 10 loaded CI-like runs.
                await #expect(throws: Never.self, performing: {
                    try await app.client.get("http://127.0.0.1:\(remoteAppPort)/json") { $0.timeout = .seconds(30) }
                })
                await #expect(throws: HTTPClientError.deadlineExceeded) {
                    try await app.client.get("http://127.0.0.1:\(remoteAppPort)/stalling") {
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
                        let response = try await app.client.get("http://127.0.0.1:\(remoteAppPort)/status/201")
                        #expect(response.status.code == 201)
                        // Server shutdown handled by task cancellation
                        return "bar"
                    } catch {
                        // Server shutdown handled by task cancellation
                        throw error
                    }
                }

                try await withRunningApp(app: app) { port in
                    let res = try await app.client.get("http://127.0.0.1:\(port)/foo")
                    try #expect(await res.body.string() == "bar")
                }
            }
        }
    }

    @Test("Test Client Logging", .disabled("Broken in AHC"), .bug("https://github.com/swift-server/async-http-client/issues/854"))
    func testClientLogging() async throws {
        try await withRemoteApp { remoteApp, remoteAppPort in
            let logHandler = InMemoryLogHandler()
            let logger = Logger(label: "codes.vapor.test", factory: { _ in
                logHandler
            })
            try await withApp(logger: logger) { app in
                _ = try await app.client.get("http://127.0.0.1:\(remoteAppPort)/status/201")

                #expect(logHandler.metadata["ahc-request-id"] != nil)
            }
        }
    }

    @Test("Test URL Client Request with Invalid URL Does Not Crash", .bug("https://github.com/vapor/vapor/issues/2716"))
    func testGH2716() async throws {
        try await withApp { app in
            app.get("client") { req in
                let response = try await app.client.get("htp://localhost/status/2 1")
                return response.description
            }

            try await app.testing(method: .running).test(.get, "/client") { res in
                #expect(res.status.code == 500)
            }
        }
    }
    #endif

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

    // MARK: - Helpers
    func withRemoteApp<T: Sendable>(_ block: @Sendable (Application, Int) async throws -> T) async throws -> T {
        let remoteApp = try await Application(.testing, configReader: testConfigReader)
        remoteApp.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

        remoteApp.get("json") { _ in
            SomeJSON()
        }

        remoteApp.get("status", ":status") { req in
            let status = try req.parameters.require("status", as: Int.self)
            return HTTPResponse.Status(code: status)
        }

        remoteApp.post("anything") { req -> AnythingResponse in
            let headers = req.headers.reduce(into: [String: String]()) {
                $0[$1.name.canonicalName] = $1.value
            }

            let json = try JSONDecoder().decode([String: String].self, from: req.body.data!)

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

    @Test("Returning a ClientResponse forwards its body", .timeLimit(.minutes(1)))
    func testClientResponseEncodesItsBody() async throws {
        try await withApp { app in
            // Proxy shape: a handler returning a ClientResponse whose body is a live stream. The body
            // used to be dropped entirely, so this answered 200 with nothing in it.
            app.get("proxied") { _ -> ClientResponse in
                var headers = HTTPFields()
                headers.contentType = .plainText
                return ClientResponse(
                    status: .created,
                    headers: headers,
                    body: try .init(stream: { writer in
                        try await writer.write("hello ")
                        try await writer.write("world")
                    }, count: 11)
                )
            }

            try await app.test(method: .running) { runner in
                let res = try await runner.sendRequest(.get, "/proxied")
                #expect(res.status == .created)
                try #expect(await res.body.requireString() == "hello world")
                // A declared length survives the proxy instead of being re-framed as chunked.
                #expect(res.headers[.contentLength] == "11")
            }
        }
    }

    @Test("Returning a ClientResponse of unknown length is chunked", .timeLimit(.minutes(1)))
    func testClientResponseWithUnknownLengthIsChunked() async throws {
        try await withApp { app in
            app.get("proxied") { _ -> ClientResponse in
                ClientResponse(status: .ok, body: .init(stream: { writer in
                    try await writer.write("streamed")
                }))
            }

            try await app.test(method: .running) { runner in
                let res = try await runner.sendRequest(.get, "/proxied")
                try #expect(await res.body.requireString() == "streamed")
                #expect(res.headers[.contentLength] == nil)
            }
        }
    }

    @Test("Returning a ClientResponse strips the origin's hop-by-hop headers", .timeLimit(.minutes(1)))
    func testClientResponseStripsHopByHopHeaders() async throws {
        try await withApp { app in
            app.get("proxied") { _ -> ClientResponse in
                var headers = HTTPFields()
                // What an origin server might have sent us. None of it describes the hop between this
                // server and its own client.
                headers[.connection] = "close, X-Origin-Only"
                headers[.upgrade] = "websocket"
                headers[HTTPField.Name("Keep-Alive")!] = "timeout=5"
                headers[HTTPField.Name("X-Origin-Only")!] = "should not be forwarded"
                headers[HTTPField.Name("X-Kept")!] = "end-to-end"
                return ClientResponse(status: .ok, headers: headers, body: .init(string: "body"))
            }

            try await app.test(method: .running) { runner in
                let res = try await runner.sendRequest(.get, "/proxied")
                try #expect(await res.body.requireString() == "body")

                #expect(res.headers[.upgrade] == nil)
                #expect(res.headers[HTTPField.Name("Keep-Alive")!] == nil)
                // Named by `Connection`, so hop-by-hop for that hop too.
                #expect(res.headers[HTTPField.Name("X-Origin-Only")!] == nil)
                // End-to-end fields are untouched.
                #expect(res.headers[HTTPField.Name("X-Kept")!] == "end-to-end")
            }
        }
    }

    @Test("A client response bounds how much it will buffer")
    func testClientResponseMaxBodySize() async throws {
        struct Payload: Content { var value: String }

        var headers = HTTPFields()
        headers.contentType = .json
        let response = ClientResponse(
            status: .ok,
            headers: headers,
            body: .init(stream: { writer in
                try await writer.write(#"{"value":""#)
                try await writer.write(String(repeating: "x", count: 4096))
                try await writer.write(#""}"#)
            }),
            maxBodySize: 512
        )

        await #expect(throws: Abort.self) {
            _ = try await response.content.decode(Payload.self)
        }

        // Streaming is not bounded by it - the ceiling is on holding the whole body in memory.
        var seen = 0
        try await response.body.withStreamingBytes { seen += $0.byteCount }
        #expect(seen == 4108)
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
