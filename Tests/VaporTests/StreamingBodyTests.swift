import Vapor
import VaporTesting
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import HTTPTypes
import ServiceLifecycle
import Logging
import Testing
import RoutingKit

@Suite("Streaming Body Tests")
struct StreamingBodyTests {

    @Test("Server writes a buffered response body")
    func testBufferedResponse() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("buffered") { _ in "Hello, buffered, world!" }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/buffered"), timeout: .seconds(10)
                )
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == "Hello, buffered, world!")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server streams an async-stream response body in chunks")
    func testAsyncStreamResponse() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("stream") { _ -> Response in
                Response(status: .ok, body: .init(asyncStream: { writer in
                    try await writer.write(.buffer(ByteBuffer(string: "Hello, ")))
                    try await writer.write(.buffer(ByteBuffer(string: "streaming, ")))
                    try await writer.write(.buffer(ByteBuffer(string: "world!")))
                    try await writer.write(.end)
                }, count: -1))
            }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/stream"), timeout: .seconds(10)
                )
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == "Hello, streaming, world!")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server streams an empty async-stream response body")
    func testEmptyAsyncStreamResponse() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("empty") { _ -> Response in
                Response(status: .ok, body: .init(asyncStream: { writer in
                    try await writer.write(.end)
                }, count: -1))
            }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/empty"), timeout: .seconds(10)
                )
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == "")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Client times out when the handler does not respond in time")
    func testSlowHandlerTimesOut() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("slow") { _ -> String in
                try await Task.sleep(for: .seconds(1))
                return "late"
            }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                await #expect(throws: (any Error).self) {
                    _ = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/slow"), timeout: .milliseconds(200)
                    )
                }

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server streams a large multi-chunk async-stream response body")
    func testLargeMultiChunkAsyncStreamResponse() async throws {
        let chunkCount = 500
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("many") { _ -> Response in
                Response(status: .ok, body: .init(asyncStream: { writer in
                    for _ in 0..<chunkCount {
                        try await writer.write(.buffer(ByteBuffer(string: "x")))
                    }
                    try await writer.write(.end)
                }, count: -1))
            }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/many"), timeout: .seconds(10)
                )
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == String(repeating: "x", count: chunkCount))

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    private struct MidStreamError: Error {}

    @Test("Server survives an error thrown mid-stream")
    func testServerErrorMidStreamDoesNotBreakServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("error-mid-stream") { _ -> Response in
                Response(status: .ok, body: .init(asyncStream: { writer in
                    try await writer.write(.buffer(ByteBuffer(string: "partial")))
                    try await writer.write(.error(MidStreamError()))
                }, count: -1))
            }
            app.get("ok") { _ in "ok" }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                // The errored request either fails while collecting or returns a truncated
                // body — either is acceptable, we only require the server not to crash.
                do {
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/error-mid-stream"), timeout: .seconds(10)
                    )
                    let body = try await resp.body.collect(upTo: 1 << 20).string
                    #expect(body != "partial-complete")
                } catch {
                    // Truncated/failed body is expected.
                }

                // The server must keep serving subsequent requests.
                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/ok"), timeout: .seconds(10)
                )
                #expect(ok.status == .ok)
                #expect(try await ok.body.collect(upTo: 1 << 20).string == "ok")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server survives a client aborting mid-stream")
    func testClientAbortMidStreamDoesNotBreakServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("firehose") { _ -> Response in
                Response(status: .ok, body: .init(asyncStream: { writer in
                    for _ in 0..<100_000 {
                        try await writer.write(.buffer(ByteBuffer(string: "x")))
                    }
                    try await writer.write(.end)
                }, count: -1))
            }
            app.get("ok") { _ in "ok" }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                // Abort mid-stream: collect with a tiny limit so the client gives up and
                // drops the connection before the server finishes streaming.
                await #expect(throws: (any Error).self) {
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/firehose"), timeout: .seconds(10)
                    )
                    _ = try await resp.body.collect(upTo: 16)
                }

                // The server must keep serving subsequent requests.
                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/ok"), timeout: .seconds(10)
                )
                #expect(ok.status == .ok)
                #expect(try await ok.body.collect(upTo: 1 << 20).string == "ok")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server streams an EventLoop-based stream response body in chunks")
    func testStreamResponse() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("stream") { _ -> Response in
                Response(status: .ok, body: .init(stream: { writer in
                    writer.write(.buffer(ByteBuffer(string: "Hello, ")), promise: nil)
                    writer.write(.buffer(ByteBuffer(string: "legacy, ")), promise: nil)
                    writer.write(.buffer(ByteBuffer(string: "world!")), promise: nil)
                    writer.write(.end, promise: nil)
                }, count: -1))
            }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/stream"), timeout: .seconds(10)
                )
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == "Hello, legacy, world!")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }
}
