import Vapor
import VaporTesting
import AsyncHTTPClient
import Testing
import HTTPTypes
import Synchronization
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

            try await app.testing { client in
                let decoded = try await client.post("/decode", content: FooContent())
                #expect(decoded.status == .ok)
                try #expect(await decoded.body.requireString().contains("decoded!"))

                // The content type is overridden after encoding, so the handler sees a body it
                // can only decode by naming the format explicitly.
                let badHeader = try await client.post("/decode-bad-header") { req in
                    try req.content.encode(FooContent())
                    req.headers.contentType = .audio
                }
                #expect(badHeader.status == .ok)
                try #expect(await badHeader.body.requireString().contains("decoded!"))
            }
        }
    }

    @Test
    func withAppConfiguration() async throws {
        try await withApp { app in
            try await app.testing { client in
                let res = try await client.get("/hello")
                #expect(res.status == .notFound)
            }
        }

        func configure(_ app: Application) async throws {
            app.get("hello") { req async -> String in
                "Hello, world!"
            }
        }

        try await withApp(configure: configure) { app in
            try await app.testing { client in
                let res = try await client.get("/hello")
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

            try await app.testing(.running) { client in
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
                let streamsCompleted = Mutex(0)
                app.get("stream") { _ in
                    Response(body: .init(stream: { writer in
                        try await writer.write("alpha")
                        try await writer.write("beta")
                        streamsCompleted.withLock { $0 += 1 }
                    }))
                }

                try await app.testing(method) { client in
                    // Streaming: nothing is buffered until something asks.
                    let read = try await client.get("/stream")
                    #expect(read.status == .ok, "\(method)")
                    #expect(read.body.string == nil, "\(method)")

                    let seen = Mutex("")
                    try await read.body.withStreamingBytes { span in
                        let chunk = String(decoding: span.withUnsafeBytes { unsafe Array($0) }, as: UTF8.self)
                        seen.withLock { $0 += chunk }
                    }
                    #expect(seen.withLock { $0 } == "alphabeta", "\(method)")

                    // Ignored: a test that only looks at the status leaves the body alone.
                    let ignored = try await client.get("/stream")
                    #expect(ignored.status == .ok, "\(method)")
                }

                // Both streams ran to completion - the ignored one was drained on the way out
                // instead of being dropped, which would have cancelled it mid-write.
                #expect(streamsCompleted.withLock { $0 } == 2, "\(method)")
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
                #expect(client.port == nil)

                let response = try await client.get("/echo?name=vapor")
                #expect(response.status == .ok)
                try #expect(await response.content.decode(String.self) == "/echo|name=vapor")

                // Same normalisation as the live client: a bare path is rooted before routing.
                let noLeadingSlash = try await client.get("echo?name=vapor")
                #expect(noLeadingSlash.status == .ok)
                try #expect(await noLeadingSlash.content.decode(String.self) == "/echo|name=vapor")

                // Client options only shape a connection, and in memory there isn't one.
                try await client.withOptions(.init(timeout: .milliseconds(1))) { client in
                    #expect(client.baseURL == nil)
                    try #expect(await client.get("/echo").status == .ok)
                }
            }
        }
    }

    @Test("Live client options configure the HTTP client, and withOptions adds another against the same server")
    func liveClientOptions() async throws {
        try await withApp { app in
            app.get("redirect") { $0.redirect(to: "target", redirectType: .normal) }
            app.get("target") { _ in "target" }

            var noRedirects = HTTPClient.Configuration.singletonConfiguration
            noRedirects.redirectConfiguration = .disallow

            try await app.testing(.running, options: .live(clientOptions: .init(configuration: noRedirects))) { client in
                let port = try #require(client.port)
                #expect(port == client.baseURL?.port)

                try #expect(await client.get("redirect").status == .seeOther)

                // Default options mean `HTTPClient.shared`, which follows redirects.
                try await client.withOptions(.init()) { following in
                    #expect(following.port == port)
                    let response = try await following.get("redirect")
                    #expect(response.status == .ok)
                    try #expect(await response.body.requireString() == "target")
                }

                // The outer client kept its own configuration.
                try #expect(await client.get("redirect").status == .seeOther)
            }
        }
    }

    @Test("Live client timeout caps a request's timeout without overriding a shorter one", .timeLimit(.minutes(1)))
    func liveClientTimeoutIsACeiling() async throws {
        func slow(_ app: Application) {
            app.get("slow") { _ -> String in
                try await Task.sleep(for: .seconds(2))
                return "done"
            }
        }

        // Separate apps, because a server that has been run and stopped can't be run again.

        // A request asking for less than the client's 30 seconds gets less. Overwriting it
        // would wait the handler out and succeed.
        try await withApp(configure: slow) { app in
            try await app.testing(.running) { client in
                _ = await #expect(throws: (any Error).self) {
                    try await client.get("slow") { $0.timeout = .milliseconds(200) }
                }
            }
        }

        // And a request left at its default can't outlast the client's.
        try await withApp(configure: slow) { app in
            try await app.testing(.running, options: .live(clientOptions: .init(timeout: .milliseconds(200)))) { client in
                _ = await #expect(throws: (any Error).self) {
                    try await client.get("slow")
                }
            }
        }
    }
}
