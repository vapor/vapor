#if OpenAPI
import HTTPTypes
import RoutingKit
import Testing
import Vapor
@testable import VaporOpenAPI
import VaporTesting

private struct Pet: Codable { var name: String }
private let info = OpenAPIInfo(title: "Pets & Co", version: "1.0.0")

@Suite("OpenAPI documentation routes")
struct OpenAPIDocumentationTests {
    @Test("The document is served as sorted JSON next to the page")
    func document() async throws {
        try await withApp { app in
            app.openAPI(response: .type(Pet.self)).get("pets") { _ in "pets" }
            app.routes.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let response = try await client.get("/docs/openapi.json")
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)
                let json = try await response.body.requireString()
                #expect(json.hasPrefix(#"{"components":{"schemas":{"Pet":"#))
                #expect(json.contains(#""/pets":{"get":"#))
            }
        }
    }

    @Test("The page loads the document from next to it, with the API's title")
    func page() async throws {
        try await withApp { app in
            app.routes.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let response = try await client.get("/docs")
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
                let html = try await response.body.requireString()
                #expect(html.contains(#"<elements-api apiDescriptionUrl="./docs/openapi.json""#))
                // Escaped, so the title can't break the page.
                #expect(html.contains("<title>Pets &amp; Co</title>"))
            }
        }
    }

    @Test("A custom title replaces the API's")
    func customTitle() async throws {
        try await withApp { app in
            app.routes.openAPIDocumentation("docs", info: info, title: "Internal API")
            try await app.testing { client in
                let html = try await client.get("/docs").body.requireString()
                #expect(html.contains("<title>Internal API</title>"))
            }
        }
    }

    @Test("Under a group, the page still finds the document")
    func underGroup() async throws {
        try await withApp { app in
            app.grouped("api").openAPIDocumentation("docs", of: app.routes, info: info)
            try await app.testing { client in
                let document = try await client.get("/api/docs/openapi.json")
                #expect(document.status == .ok)
                let html = try await client.get("/api/docs").body.requireString()
                // Relative, so from /api/docs it resolves to /api/docs/openapi.json.
                #expect(html.contains(#"apiDescriptionUrl="./docs/openapi.json""#))
            }
        }
    }

    @Test("At the root, the page loads openapi.json")
    func atRoot() async throws {
        try await withApp { app in
            app.routes.openAPIDocumentation(info: info)
            try await app.testing { client in
                let document = try await client.get("/openapi.json")
                #expect(document.status == .ok)
                let html = try await client.get("/").body.requireString()
                #expect(html.contains(#"apiDescriptionUrl="./openapi.json""#))
            }
        }
    }

    @Test("The documentation routes aren't in the document")
    func hidden() async throws {
        try await withApp { app in
            app.get("pets") { _ in "pets" }
            app.routes.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let json = try await client.get("/docs/openapi.json").body.requireString()
                #expect(json.contains("/pets"))
                #expect(!json.contains("/docs"))
            }
        }
    }

    @Test("A route that can't be described makes the document fail")
    func failure() async throws {
        try await withApp { app in
            app.get("proxy", "**") { _ in "x" }
            app.routes.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let document = try await client.get("/docs/openapi.json")
                #expect(document.status == .internalServerError)
            }
        }
    }

    @Test("With a trailing slash, the page still finds the document")
    func trailingSlash() async throws {
        try await withApp { app in
            app.routes.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let html = try await client.get("/docs/").body.requireString()
                // From /docs/ the browser resolves this to /docs/openapi.json.
                #expect(html.contains(#"apiDescriptionUrl="./openapi.json""#))
            }
        }
    }

    @Test("At a group's root, the page finds the document under the group")
    func groupRoot() async throws {
        try await withApp { app in
            app.grouped("api").openAPIDocumentation(of: app.routes, info: info)
            try await app.testing { client in
                let document = try await client.get("/api/openapi.json")
                #expect(document.status == .ok)
                let html = try await client.get("/api").body.requireString()
                // From /api the browser resolves this to /api/openapi.json, not /openapi.json.
                #expect(html.contains(#"apiDescriptionUrl="./api/openapi.json""#))
            }
        }
    }

    @Test(
        "The document's URL is relative to the page it's on",
        arguments: [
            ("/docs", "./docs/openapi.json"),
            ("/api/docs", "./docs/openapi.json"),
            ("/docs/", "./openapi.json"),
            ("/", "./openapi.json"),
            ("/api", "./api/openapi.json"),
            // Paths arrive percent-encoded, and stay as they are.
            ("/my%20docs", "./my%20docs/openapi.json"),
            ("/%D0%B4%D0%BE%D0%BA", "./%D0%B4%D0%BE%D0%BA/openapi.json"),
            ("/v1:docs", "./v1:docs/openapi.json"),
        ]
    )
    func documentURL(page: String, expected: String) {
        #expect(StoplightPage.documentURL(from: page) == expected)
    }

    @Test("The documentation routes don't keep the application alive")
    func noRetainCycle() async throws {
        weak var released: Application?
        do {
            let app = try Application(.testing)
            app.routes.openAPIDocumentation("docs", info: info)
            try await app.shutdown()
            released = app
        }
        #expect(released == nil)
    }

    @Test("A page whose path has a space finds the document")
    func encodedPath() async throws {
        try await withApp { app in
            app.openAPIDocumentation("my docs", info: info)
            try await app.testing { client in
                let html = try await client.get("/my%20docs").body.requireString()
                #expect(html.contains(#"apiDescriptionUrl="./my%20docs/openapi.json""#))
                let document = try await client.get("/my%20docs/openapi.json")
                #expect(document.status == .ok)
            }
        }
    }
}
#endif
