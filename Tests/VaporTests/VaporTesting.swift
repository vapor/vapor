import Vapor
import VaporTesting
import Testing
import HTTPTypes
import RoutingKit

/// Tests to make sure Vapor's swift-testing integration works.
@Suite("Vapor Testing Tests")
struct VaporTestingTests {
    /// A test to trigger multiple Vapor+swift-testing integration functions to make sure they work at all.
    @Test("Test Vapor Testing functions")
    func contentContainerDecode() async throws {
        struct FooContent: Content, Equatable {
            var message: String = "hi"
        }
        struct FooDecodable: Decodable, Equatable {
            var message: String = "hi"
        }

        try await withApp { app in
            app.routes.post("decode") { req async throws -> String in
                #expect(try await req.content.decode(FooContent.self) == FooContent())
                #expect(try await req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.post, "/decode") { req in
                try req.content.encode(FooContent())
            } afterResponse: { res in
                #expect(res.status == .ok)
                try #expect(await res.body.string()?.contains("decoded!") ?? false)
            }

            app.routes.post("decode-bad-header") { req async throws -> String in
                #expect(req.headers.contentType == .audio)
                await #expect(
                    performing: {
                        try await req.content.decode(FooContent.self)
                    }, throws: { error in
                        guard let abort = error as? Abort,
                              abort.status == .unsupportedMediaType else {
                            Issue.record("Unexpected error: \(error)")
                            return false
                        }
                        return true
                    }
                )
                #expect(try await req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.post, "/decode-bad-header") { req in
                try req.content.encode(FooContent())
                req.headers.contentType = .audio
            } afterResponse: { res in
                #expect(res.status == .ok)
                try #expect(await res.body.string()?.contains("decoded!") ?? false)
            }
        }
    }

    @Test
    func withAppConfiguration() async throws {
        try await withApp { app in
            try await app.testing().test(.get, "hello") { res in
                #expect(res.status == .notFound)
            }
        }

        func configure(_ app: Application) async throws {
            app.get("hello") { req async -> String in
                "Hello, world!"
            }
        }

        try await withApp(configure: configure) { app in
            try await app.testing().test(.get, "hello") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Hello, world!")
            }
        }
    }

    @Test("Live client resolves a bare path against the running server")
    func liveClientResolvesPaths() async throws {
        try await withApp { app in
            // Echoes what the server actually received, so the assertions are on the resolved
            // request rather than on whatever the client thought it sent.
            app.get("echo") { req -> String in
                "\(req.url.path)|\(req.url.query ?? "")"
            }

            try await app.testing(.running()) { client in
                let base = try #require(client.baseURL)
                #expect(base.scheme == "http")
                #expect(base.host == "127.0.0.1")
                let port = try #require(base.port)
                #expect(port > 0)

                let leadingSlash = try await client.get("/echo")
                #expect(leadingSlash.status == .ok)
                try #expect(await leadingSlash.content.decode(String.self) == "/echo|")

                let noLeadingSlash = try await client.get("echo")
                #expect(noLeadingSlash.status == .ok)
                try #expect(await noLeadingSlash.content.decode(String.self) == "/echo|")

                let withQuery = try await client.get("/echo?name=vapor&n=1")
                #expect(withQuery.status == .ok)
                try #expect(await withQuery.content.decode(String.self) == "/echo|name=vapor&n=1")

                // A full URL is left alone, so a test can point the same client somewhere else.
                let absolute = try await client.get(URI(string: "http://127.0.0.1:\(port)/echo?absolute=1"))
                #expect(absolute.status == .ok)
                try #expect(await absolute.content.decode(String.self) == "/echo|absolute=1")

                let missing = try await client.get("/nope")
                #expect(missing.status == .notFound)
            }
        }
    }

    @Test("In-memory client has no base URL and passes the path straight through")
    func inMemoryClientPassesPathThrough() async throws {
        try await withApp { app in
            app.get("echo") { req -> String in
                "\(req.url.path)|\(req.url.query ?? "")"
            }

            try await app.testing { client in
                #expect(client.baseURL == nil)

                let response = try await client.get("/echo?name=vapor")
                #expect(response.status == .ok)
                try #expect(await response.content.decode(String.self) == "/echo|name=vapor")

                // Same normalisation as the live client: a bare path is rooted before routing.
                let noLeadingSlash = try await client.get("echo?name=vapor")
                #expect(noLeadingSlash.status == .ok)
                try #expect(await noLeadingSlash.content.decode(String.self) == "/echo|name=vapor")
            }
        }
    }
}
