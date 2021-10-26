#if compiler(>=5.5) && canImport(_Concurrency)
import Vapor
import XCTest

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
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
        let app = Application(.testing)
        defer { app.shutdown() }

        let res = try await app.client.get("https://httpbin.org/json")

        let encoded = try JSONEncoder().encode(res)
        let decoded = try JSONDecoder().decode(ClientResponse.self, from: encoded)

        XCTAssertEqual(res, decoded)
    }

    func testClientBeforeSend() async throws {
        let app = Application()
        defer { app.shutdown() }
        try app.boot()

        let res = try await app.client.post("http://httpbin.org/anything") { req in
            try req.content.encode(["hello": "world"])
        }

        struct HTTPBinAnything: Codable {
            var headers: [String: String]
            var json: [String: String]
        }
        let data = try res.content.decode(HTTPBinAnything.self)
        XCTAssertEqual(data.json, ["hello": "world"])
        XCTAssertEqual(data.headers["Content-Type"], "application/json; charset=utf-8")
    }

    func testBoilerplateClient() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("foo") { req async throws -> String in
            do {
                let response = try await req.client.get("https://httpbin.org/status/201")
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

        let res = try await app.client.get("http://localhost:8080/foo")
        XCTAssertEqual(res.body?.string, "bar")

        try app.running?.onStop.wait()
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
        print("We are testing client logging")
        let app = Application(.testing)
        defer { app.shutdown() }
        let logs = TestLogHandler()
        app.logger = logs.logger

        _ = try await app.client.get("https://httpbin.org/json")

        let metadata = logs.getMetadata()
        XCTAssertNotNil(metadata["ahc-request-id"])
    }
}
#endif
