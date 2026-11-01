#if OpenAPI
import HTTPTypes
import RoutingKit
import Testing
import Vapor
@testable import VaporOpenAPI
import VaporTesting

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private struct Pet: Codable {
    var id: Int
    var name: String
}
private struct Paging: Codable { var page: Int? }

/// The document for the routes `configure` registers, as JSON with sorted keys.
private func document(_ configure: (Application) throws -> Void) async throws -> String {
    try await withApp { app in
        try configure(app)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
        return String(decoding: try encoder.encode(document), as: UTF8.self)
    }
}

@Suite("Routes OpenAPI document")
struct RoutesOpenAPITests {
    @Test("A described route becomes an operation under its path")
    func operation() async throws {
        let json = try await document { app in
            app.openAPI(tags: ["Pets"], summary: "Get a pet", operationID: "getPet", response: .type(Pet.self))
                .get("pets", ":id") { _ in "pet" }
        }
        #expect(json.contains(#""openapi":"3.2.1""#))
        #expect(json.contains(#""info":{"title":"Pets","version":"1.0.0"}"#))
        #expect(json.contains(#""/pets/{id}":{"get":{"#))
        #expect(json.contains(#""operationId":"getPet""#))
        #expect(json.contains(#"{"in":"path","name":"id","required":true,"schema":{"type":"string"}}"#))
        #expect(
            json.contains(##""200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Pet"}}},"description":"OK"}"##))
        #expect(json.contains(#""components":{"schemas":{"Pet":"#))
        #expect(json.contains(#""tags":[{"name":"Pets"}]"#))
    }

    @Test("Routes on the same path share it, one operation per method")
    func samePath() async throws {
        let json = try await document { app in
            app.get("pets") { _ in "list" }
            app.openAPI(body: .type(Pet.self), statusCode: .created).post("pets") { _ in "created" }
        }
        #expect(json.contains(#""/pets":{"get":"#))
        #expect(json.contains(#""post":{"#))
        #expect(json.contains(#""201":{"description":"Created"}"#))
        #expect(
            json.contains(
                ##""requestBody":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Pet"}}},"required":true}"##))
    }

    @Test("Hidden routes are left out")
    func hidden() async throws {
        let json = try await document { app in
            app.hiddenFromOpenAPI().get("health") { _ in "ok" }
            app.get("pets") { _ in "list" }
        }
        #expect(!json.contains("/health"))
        #expect(json.contains("/pets"))
    }

    @Test("Auth adds a security requirement and its scheme")
    func auth() async throws {
        let json = try await document { app in
            app.openAPI(auth: [.bearer()]).get("me") { _ in "me" }
        }
        #expect(json.contains(#""security":[{"http_bearer":[]}]"#))
        #expect(json.contains(#""securitySchemes":{"http_bearer":{"scheme":"bearer","type":"http"}}"#))
    }

    @Test("Query parameters come from the type")
    func query() async throws {
        let json = try await document { app in
            app.openAPI(query: .type(Paging.self)).get("pets") { _ in "list" }
        }
        #expect(json.contains(#"{"in":"query","name":"page","schema":{"format":"int64","type":"integer"}}"#))
    }

    @Test("A catch-all route fails, naming the route and how to hide it")
    func catchall() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await document { app in app.get("proxy", "**") { _ in "x" } }
        }
        #expect(
            "\(error!)" == "GET /proxy/**: a catch-all path (**) can't be described in OpenAPI. Hide the route with hiddenFromOpenAPI().")
    }

    @Test("Two different schemes under one ID fail")
    func authCollision() async throws {
        await #expect(throws: (any Error).self) {
            try await document { app in
                app.openAPI(auth: [.bearer(id: "token")]).get("a") { _ in "a" }
                app.openAPI(auth: [.basic(id: "token")]).get("b") { _ in "b" }
            }
        }
    }
}
#endif
