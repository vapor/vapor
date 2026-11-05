#if OpenAPI
import HTTPTypes
import RoutingKit
import Testing
import Vapor
import VaporOpenAPI
import VaporTesting

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// No `@testable` here, as in PublicAPITests: this fails to compile if anything a user needs to
// describe routes and serve their document is accidentally internal.

private struct Model: Codable { var id: Int }

@Suite("Public documentation API")
struct PublicDocumentationAPITests {
    @Test("Routes can be described, documented and served from outside the module")
    func routesAndDocumentation() async throws {
        try await withApp { app in
            app.openAPI(summary: "Get a model", response: .type(Model.self)).get("models", ":id") { _ in "model" }
            app.hiddenFromOpenAPI().get("health") { _ in "ok" }
            let info = OpenAPIInfo(title: "Models", version: "1.0.0")
            app.openAPIDocumentation("docs", info: info)
            app.routes.openAPIDocumentation(["routes-docs"], of: app, info: info)
            app.grouped("admin").openAPIDocumentation(["docs"], of: app, info: info, title: "Admin")
            // A document built by hand can be returned as it is, and holds no reference to the app.
            let document: OpenAPIDocument = try app.routes.openAPI(info: info)
            app.get("spec") { _ in document }
            let json: Data = try document.json()
            #expect(!json.isEmpty)
            try await app.testing { client in
                for path in ["/docs/openapi.json", "/routes-docs/openapi.json", "/admin/docs/openapi.json", "/spec"] {
                    let response = try await client.get(URI(path: path))
                    #expect(response.status == .ok, "\(path)")
                }
            }
        }
    }

    @Test("A route that can't be described is reported by a public error")
    func publicError() async throws {
        try await withApp { app in
            app.get("files", "**") { _ in "file" }
            do {
                _ = try app.routes.openAPI(info: OpenAPIInfo(title: "Files", version: "1.0.0"))
                Issue.record("Expected the document to fail")
            } catch let error as OpenAPIDocumentError {
                #expect(error.route == "GET /files/**")
                #expect(error.reason.contains("hiddenFromOpenAPI()"))
            }
        }
    }
}
#endif
