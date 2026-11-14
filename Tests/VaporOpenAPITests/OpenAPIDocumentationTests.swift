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

private struct Pet: Codable { var name: String }
/// The body of an error Vapor responds with.
private struct ErrorBody: Decodable { var reason: String }
private let info = OpenAPIInfo(title: "Pets & Co", version: "1.0.0")

@Suite("OpenAPI documentation routes")
struct OpenAPIDocumentationTests {
    @Test("The document is served as sorted JSON next to the page")
    func document() async throws {
        try await withApp { app in
            app.openAPI(response: .type(Pet.self)).get("pets") { _ in "pets" }
            app.openAPIDocumentation("docs", info: info)
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
            app.openAPIDocumentation("docs", info: info)
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
            app.openAPIDocumentation("docs", info: info, title: "Internal API")
            try await app.testing { client in
                let html = try await client.get("/docs").body.requireString()
                #expect(html.contains("<title>Internal API</title>"))
            }
        }
    }

    @Test("The documentation routes aren't in the document")
    func hidden() async throws {
        try await withApp { app in
            app.get("pets") { _ in "pets" }
            app.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let json = try await client.get("/docs/openapi.json").body.requireString()
                #expect(json.contains("/pets"))
                #expect(!json.contains("/docs"))
            }
        }
    }

    @Test("A route that can't be described doesn't stop the boot, and the document is a 500 naming it")
    func failure() async throws {
        try await withApp { app in
            let pets = app.openAPI(operationID: "pets")
            pets.get("a") { _ in "a" }
            pets.get("b") { _ in "b" }
            app.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let document = try await client.get("/docs/openapi.json")
                let body = try await document.body.requireString()
                let reason = try JSONDecoder().decode(ErrorBody.self, from: Data(body.utf8)).reason
                #expect(document.status == .internalServerError)
                // Not a release build, so the client is told which route and why.
                #expect(reason.contains(#"GET /b: its operation ID "pets" is also GET /a's"#))
                // The rest of the app, the page included, is served as usual.
                let route = try await client.get("/a")
                let page = try await client.get("/docs")
                #expect(route.status == .ok)
                #expect(page.status == .ok)
            }
        }
    }

    @Test("Routes registered after the documentation, before boot, are in the document")
    func laterRoutes() async throws {
        try await withApp { app in
            app.openAPIDocumentation("docs", info: info)
            app.get("pets") { _ in "pets" }
            try await app.testing { client in
                let json = try await client.get("/docs/openapi.json").body.requireString()
                #expect(json.contains(#""/pets":"#))
            }
        }
    }

    @Test("The document is built once, at boot, so routes added later aren't in it")
    func builtOnce() async throws {
        try await withApp { app in
            app.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let before = try await client.get("/docs/openapi.json").body.requireString()
                // Booted but not started, so configuration is still open.
                app.get("late") { _ in "late" }
                let after = try await client.get("/docs/openapi.json").body.requireString()
                #expect(after == before)
                #expect(!after.contains("/late"))
            }
        }
    }

    @Test("Routes another lifecycle handler adds in a later didBoot aren't in the document")
    func laterDidBoot() async throws {
        try await withApp { app in
            app.openAPIDocumentation("docs", info: info)
            app.addLifecycleHandler(AddsRoute())
            try await app.testing { client in
                #expect(try await client.get("/added").status == .ok)
                let json = try await client.get("/docs/openapi.json").body.requireString()
                #expect(!json.contains("/added"))
            }
        }
    }

    @Test("Until the application has booted, the document is a 503 saying why")
    func beforeBoot() async throws {
        try await withApp { app in
            let builder = OpenAPIDocumentationBuilder(info: info)
            let error = #expect(throws: Abort.self) { try builder.response() }
            #expect(error?.status == .serviceUnavailable)
            #expect(error?.reason.contains("registered after it booted") == true)
            await builder.didBoot(app)
            let response = try builder.response()
            #expect(response.headers.contentType == .json)
        }
    }

    @Test("Documentation registered after boot, or in a lifecycle handler's didBoot, is a 503 saying why")
    func registeredAfterBoot() async throws {
        try await withApp { app in
            try await app.boot()
            app.openAPIDocumentation("docs", info: info)
            try await app.testing { client in
                let document = try await client.get("/docs/openapi.json")
                let reason = try await document.body.requireString()
                #expect(document.status == .serviceUnavailable)
                #expect(reason.contains("registered after it booted"))
            }
        }
        try await withApp { app in
            app.addLifecycleHandler(AddsDocumentation())
            try await app.testing { client in
                let document = try await client.get("/docs/openapi.json")
                #expect(document.status == .serviceUnavailable)
            }
        }
    }

    @Test(
        "The page finds the document, under a group, at a root, with a trailing slash or a space in its path",
        arguments: [
            // Relative, so from /api/docs it resolves to /api/docs/openapi.json.
            (
                ["api"] as [PathComponent], ["docs"] as [PathComponent], "/api/docs", "./docs/openapi.json",
                "/api/docs/openapi.json"
            ),
            ([], [], "/", "./openapi.json", "/openapi.json"),
            // From /docs/ the browser resolves this to /docs/openapi.json.
            ([], ["docs"], "/docs/", "./openapi.json", "/docs/openapi.json"),
            // From /api the browser resolves this to /api/openapi.json, not /openapi.json.
            (["api"], [], "/api", "./api/openapi.json", "/api/openapi.json"),
            ([], ["my docs"], "/my%20docs", "./my%20docs/openapi.json", "/my%20docs/openapi.json"),
        ]
    )
    func pageFindsDocument(
        group: [PathComponent],
        path: [PathComponent],
        page: String,
        documentURL: String,
        document: String
    ) async throws {
        try await withApp { app in
            app.grouped(group).openAPIDocumentation(path, of: app, info: info)
            try await app.testing { client in
                let response = try await client.get(URI(string: document))
                #expect(response.status == .ok)
                let html = try await client.get(URI(string: page)).body.requireString()
                #expect(html.contains(#"apiDescriptionUrl="\#(documentURL)""#))
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

    @Test("The documentation routes don't keep the application alive, booted or not", arguments: [false, true])
    func noRetainCycle(boots: Bool) async throws {
        weak var released: Application?
        do {
            let app = try Application(.testing)
            app.openAPIDocumentation("docs", info: info)
            if boots { try await app.boot() }
            try await app.shutdown()
            released = app
        }
        #expect(released == nil)
    }
}

/// Registers the documentation when the application boots, too late for it to be built.
private struct AddsDocumentation: LifecycleHandler {
    func didBoot(_ application: Application) async throws {
        application.openAPIDocumentation("docs", info: info)
    }
}

/// Adds a route when the application boots, after the documentation's handler has run.
private struct AddsRoute: LifecycleHandler {
    func didBoot(_ application: Application) async throws {
        application.get("added") { _ in "added" }
    }
}
#endif
