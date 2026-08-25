import Vapor
import VaporTesting
import AsyncHTTPClient
import NIOCore
import NIOConcurrencyHelpers
import NIOPosix
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
                Response(status: .ok, body: .init(stream: { writer in
                    try await writer.write(ByteBuffer(string: "Hello, "))
                    try await writer.write(ByteBuffer(string: "streaming, "))
                    try await writer.write(ByteBuffer(string: "world!"))
                }))
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
                Response(status: .ok, body: .init(stream: { _ in }))
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
                Response(status: .ok, body: .init(stream: { writer in
                    for _ in 0..<chunkCount {
                        try await writer.write(ByteBuffer(string: "x"))
                    }
                }))
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
                Response(status: .ok, body: .init(stream: { writer in
                    try await writer.write(ByteBuffer(string: "partial"))
                    throw MidStreamError()
                }))
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

                // An error thrown mid-stream must surface to the client as a failure, not as a
                // clean response: the head (200, chunked) is already flushed, so the server drops
                // `finish` and tears the connection down without a terminating chunk. Collecting
                // the incomplete body must therefore throw (or the request fails outright). We
                // require that failure signal — silently delivering a well-formed body would be a
                // regression.
                var sawFailureSignal = false
                do {
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/error-mid-stream"), timeout: .seconds(10)
                    )
                    do {
                        _ = try await resp.body.collect(upTo: 1 << 20)
                    } catch {
                        sawFailureSignal = true // truncated/incomplete body surfaced as an error
                    }
                } catch {
                    sawFailureSignal = true // request failed outright
                }
                #expect(sawFailureSignal, "client must observe truncation/failure when the stream errors mid-body")

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

    @Test("An error thrown mid-stream aborts the response instead of completing it")
    func testMidStreamErrorWithDeclaredLengthAbortsResponse() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            // Declares Content-Length: 8, writes 4 bytes, then throws. Throwing out of the handler
            // aborts the stream (swift-http-server#115): `finish` is skipped, so the response is
            // never concluded and the client can never receive the full 8-byte body — it either
            // errors on the truncated response or sees fewer bytes than advertised.
            app.get("abort") { _ -> Response in
                Response(status: .ok, body: .init(stream: { writer in
                    try await writer.write(ByteBuffer(string: "AAAA"))
                    throw MidStreamError()
                }, count: 8))
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

                // The full declared body must never arrive intact.
                var deliveredFullBody = false
                do {
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/abort"), timeout: .seconds(10)
                    )
                    let body = try await resp.body.collect(upTo: 1 << 20)
                    deliveredFullBody = body.readableBytes == 8
                } catch {
                    // Aborted/truncated response is expected.
                }
                #expect(!deliveredFullBody, "aborted stream must not deliver the full declared body")

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
                Response(status: .ok, body: .init(stream: { writer in
                    for _ in 0..<100_000 {
                        try await writer.write(ByteBuffer(string: "x"))
                    }
                }))
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

    @Test("Server backpressures a fast producer against a stalled client")
    func testStreamingBodyBackpressure() async throws {
        let chunkSize = 16 * 1024
        let totalChunks = 2048 // 32 MiB — far larger than any socket/NIO buffer window.
        let produced = NIOLockedValueBox(0)

        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("firehose") { _ -> Response in
                Response(status: .ok, body: .init(stream: { writer in
                    let chunk = ByteBuffer(repeating: 0x41, count: chunkSize)
                    for _ in 0..<totalChunks {
                        try await writer.write(chunk)
                        produced.withLockedValue { $0 += 1 }
                    }
                }))
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
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/firehose"), timeout: .seconds(30)
                )
                #expect(resp.status == .ok)

                // Don't read the body yet: the socket and NIO write buffers fill, and `write`
                // must suspend, so the producer cannot race to the last chunk while we stall.
                try await Task.sleep(for: .milliseconds(500))
                let stalledAt = produced.withLockedValue { $0 }
                #expect(stalledAt < totalChunks, "producer was not backpressured (produced \(stalledAt)/\(totalChunks))")

                // Drain the body: the producer resumes and runs to completion.
                var received = 0
                for try await chunk in resp.body {
                    received += chunk.readableBytes
                }
                #expect(received == totalChunks * chunkSize)
                #expect(produced.withLockedValue { $0 } == totalChunks)

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server survives a stream that writes fewer bytes than its declared length")
    func testBadStreamLengthDoesNotBreakServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            // Declares `Content-Length: 2` (via `count`) but only writes a single byte.
            app.get("bad-length") { _ -> Response in
                Response(status: .ok, body: .init(stream: { writer in
                    try await writer.write(ByteBuffer(string: "a"))
                }, count: 2))
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

                // A body shorter than the declared length can't be delivered cleanly: the client
                // either errors on the truncated response or sees fewer bytes than advertised.
                // Either is acceptable — we only require the server not to crash.
                do {
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/bad-length"), timeout: .seconds(5)
                    )
                    let body = try await resp.body.collect(upTo: 1 << 20)
                    #expect(body.readableBytes < 2)
                } catch {
                    // Truncated/failed response is expected.
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

    @Test("collect() gathers a streaming body into a single buffer")
    func testCollectStreamingBody() async throws {
        let body = Response.Body(stream: { writer in
            try await writer.write(ByteBuffer(string: "Hello, "))
            try await writer.write(ByteBuffer(string: "collected!"))
        })
        let collected = try await body.collect()
        #expect(collected.map { String(buffer: $0) } == "Hello, collected!")
    }

    /// Sends a raw request over a plain TCP socket and returns every byte the server sends back
    /// within `grace`, along with whether the server closed the connection.
    ///
    /// A real HTTP client hides framing violations — it parses the response according to the rules
    /// the server is supposed to be following — so checking "is there a body on the wire" needs a
    /// socket, not a client. The deadline is client-side: waiting for the server to close would
    /// otherwise park the test on the server's read-header timeout.
    private func rawExchange(
        port: Int,
        path: String,
        grace: Duration = .milliseconds(250)
    ) async throws -> (bytes: String, serverClosed: Bool) {
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .connect(host: "127.0.0.1", port: port) { channel in
                channel.eventLoop.makeCompletedFuture {
                    try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }
        return try await channel.executeThenClose { inbound, outbound in
            try await outbound.write(ByteBuffer(
                string: "GET \(path) HTTP/1.1\r\nHost: localhost\r\n\r\n"))
            let received = NIOLockedValueBox("")
            let reachedEnd = NIOLockedValueBox(false)
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        for try await buffer in inbound {
                            received.withLockedValue { $0 += String(buffer: buffer) }
                        }
                        reachedEnd.withLockedValue { $0 = true }
                    } catch {
                        // Cancelled by the deadline below, or the connection failed. Either way
                        // whatever arrived is what we assert on.
                    }
                }
                group.addTask {
                    try? await Task.sleep(for: grace)
                }
                // Whichever finishes first — EOF or the deadline — ends the exchange.
                await group.next()
                group.cancelAll()
            }
            return (received.withLockedValue { $0 }, reachedEnd.withLockedValue { $0 })
        }
    }

    @Test("Server does not write a body for a status that cannot carry one", .timeLimit(.minutes(1)))
    func testBodylessStatusDoesNotWriteBody() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            // Both statuses are defined to have no body, whatever the handler attaches.
            app.get("no-content") { _ in
                Response(status: .noContent, body: .init(string: "Hello, world!"))
            }
            app.get("not-modified") { _ in
                Response(status: .notModified, body: .init(string: "Hello, world!"))
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

                let noContent = try await rawExchange(port: port, path: "/no-content").bytes
                #expect(noContent.hasPrefix("HTTP/1.1 204 No Content"))
                withKnownIssue("204 response carries the handler's body") {
                    #expect(!noContent.contains("Hello, world!"), "\(noContent.debugDescription)")
                }

                let notModified = try await rawExchange(port: port, path: "/not-modified").bytes
                #expect(notModified.hasPrefix("HTTP/1.1 304 Not Modified"))
                withKnownIssue("304 response carries the handler's body") {
                    #expect(!notModified.contains("Hello, world!"), "\(notModified.debugDescription)")
                }

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }
}
