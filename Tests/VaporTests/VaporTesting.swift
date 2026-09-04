import Vapor
import VaporTesting
import Testing
import HTTPTypes
import NIOConcurrencyHelpers
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

    @Test("Responses stream by default and an unread body is drained when the scope ends")
    func responseBodiesStreamAndAreDrained() async throws {
        for method in [Application.Method.inMemory, .running] {
            try await withApp { app in
                // Set only once the handler has written everything: proof the stream ran to the
                // end rather than being cancelled or never started.
                let streamsCompleted = NIOLockedValueBox(0)
                app.get("stream") { _ in
                    Response(body: .init(stream: { writer in
                        try await writer.write("alpha")
                        try await writer.write("beta")
                        streamsCompleted.withLockedValue { $0 += 1 }
                    }))
                }

                try await app.testing(method) { client in
                    // Streaming: nothing is buffered until something asks.
                    let read = try await client.get("/stream")
                    #expect(read.status == .ok, "\(method)")
                    #expect(read.body.string == nil, "\(method)")

                    let seen = NIOLockedValueBox("")
                    try await read.body.withStreamingBytes { span in
                        let chunk = String(decoding: span.withUnsafeBytes { unsafe Array($0) }, as: UTF8.self)
                        seen.withLockedValue { $0 += chunk }
                    }
                    #expect(seen.withLockedValue { $0 } == "alphabeta", "\(method)")

                    // Ignored: a test that only looks at the status leaves the body alone.
                    let ignored = try await client.get("/stream")
                    #expect(ignored.status == .ok, "\(method)")
                }

                // Both streams ran to completion - the ignored one was drained on the way out
                // instead of being dropped, which would have cancelled it mid-write.
                #expect(streamsCompleted.withLockedValue { $0 } == 2, "\(method)")
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
