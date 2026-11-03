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
            app.routes.openAPIDocumentation(["routes-docs"], info: info)
            app.grouped("admin").openAPIDocumentation(["docs"], of: app.routes, info: info, title: "Admin")
            // A handler can return the document as it is. It holds the app weakly, since the app
            // keeps the route, and a strong reference would keep the app alive forever.
            app.get("spec") { [weak app] _ in
                guard let app else { throw Abort(.serviceUnavailable) }
                return try app.routes.openAPI(info: info)
            }
            let document: OpenAPIDocument = try app.routes.openAPI(info: info)
            let json: Data = try document.json()
            #expect(!json.isEmpty)
        }
    }
}
#endif
