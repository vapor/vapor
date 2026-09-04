import Vapor
import Crypto
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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif


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
                    try await writer.write("Hello, ")
                    try await writer.write("streaming, ")
                    try await writer.write("world!")
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
                        try await writer.write("x")
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
                    try await writer.write("partial")
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
                try #expect(await ok.body.collect(upTo: 1 << 20).string == "ok")

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
                Response(status: .ok, body: try .init(stream: { writer in
                    try await writer.write("AAAA")
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
                try #expect(await ok.body.collect(upTo: 1 << 20).string == "ok")

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
                        try await writer.write("x")
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
                try #expect(await ok.body.collect(upTo: 1 << 20).string == "ok")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server backpressures a fast producer against a stalled client")
    func testStreamingBodyBackpressure() async throws {
        let chunkSize = 16 * 1024
        // A safety valve, not a target: a backpressured producer stalls a few hundred chunks in,
        // once the socket buffers fill. It has to clear the several MiB the writer accepts past
        // the channel's watermark, which varies with how promptly the event loop is scheduled,
        // so the cap is set well clear of that; all it does is bound what a broken run buffers.
        let maxChunks = 8192 // 128 MiB
        let produced = NIOLockedValueBox(0)

        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("firehose") { _ -> Response in
                Response(status: .ok, body: .init(stream: { writer in
                    let chunk = [UInt8](repeating: 0x41, count: chunkSize)
                    for _ in 0..<maxChunks {
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

                // A raw socket, deliberately not read from. An HTTP client can't be used here:
                // it buffers the response body internally whether or not the test iterates it, so
                // the server sees a reader that keeps consuming and is never backpressured — which
                // is exactly how this test failed in CI, reporting 2048/2048 produced.
                let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                    // A small receive buffer keeps the advertised window — and so the total the
                    // kernel can absorb — well under the body size on any host. Socket buffers
                    // autotune, and CI hosts tune their ceilings differently, so without this the
                    // test is really asserting "32 MiB doesn't fit in this machine's buffers".
                    .channelOption(.socketOption(.so_rcvbuf), value: 16 * 1024)
                    .connect(host: "127.0.0.1", port: port) { channel in
                        channel.eventLoop.makeCompletedFuture {
                            try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                        }
                    }

                try await channel.executeThenClose { _, outbound in
                    try await outbound.write(ByteBuffer(
                        string: "GET /firehose HTTP/1.1\r\nHost: localhost\r\n\r\n"))

                    // Nothing reads the socket, so the kernel receive buffer fills, then the send
                    // side, and the producer's writes must suspend. Two samples assert it is
                    // *stalled* rather than merely unfinished: a count short of the cap can just
                    // mean a slow producer, which would pass on a loaded machine whether or not
                    // backpressure works at all.
                    try await Task.sleep(for: .milliseconds(500))
                    let firstSample = produced.withLockedValue { $0 }
                    try await Task.sleep(for: .milliseconds(500))
                    let stalledAt = produced.withLockedValue { $0 }
                    #expect(
                        stalledAt == firstSample,
                        """
                        producer kept writing while the client read nothing \
                        (\(firstSample) → \(stalledAt) of \(maxChunks))
                        """)
                    #expect(
                        stalledAt < maxChunks,
                        "producer was not backpressured (produced \(stalledAt)/\(maxChunks))")

                    // No drain-and-resume check here on purpose. The producer only wakes once
                    // the channel is writable again, which means reading *everything* buffered
                    // in-process — on CI that has taken over five seconds and timed out the
                    // tests running alongside it. Delivery of a full streamed body is covered
                    // by the other tests in this suite.
                }

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server survives a stream that writes fewer bytes than its declared length",
          .bug("https://github.com/swift-server/swift-http-server/issues/116"))
    func testBadStreamLengthDoesNotBreakServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            // Declares `Content-Length: 2` (via `count`) but only writes a single byte.
            app.get("bad-length") { _ -> Response in
                Response(status: .ok, body: try .init(stream: { writer in
                    try await writer.write("a")
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
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/bad-length"), timeout: .seconds(15)
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
                try #expect(await ok.body.collect(upTo: 1 << 20).string == "ok")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("A middleware that reads the request body does not break a streaming response",
          .bug("https://github.com/vapor/vapor/issues/2933"))
    func testMiddlewareReadingBodyWithStreamingResponse() async throws {
        // The repro from the issue: a middleware peeks at the request body, and the route echoes
        // that body back as a streaming response. The old response-body stream signalled its own
        // completion, so the two readers racing over the request stream left `.end` unsent and
        // tripped "Response body stream writer deinitialized before .end or .error was sent."
        // A `ResponseBodyWriter` has no way to end the stream — the server concludes the response
        // once the closure returns — so there is no longer an end to miss.
        struct PeekingMiddleware: Middleware {
            let seen: NIOLockedValueBox<Int>

            func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                // Exactly what the issue did: read the body from a middleware, then chain on.
                let collected = try await request.body.collect(max: nil).get()
                self.seen.withLockedValue { $0 = collected?.readableBytes ?? 0 }
                return try await next.respond(to: request)
            }
        }

        let seen = NIOLockedValueBox(0)
        try await withApp { app in
            app.middleware.use(PeekingMiddleware(seen: seen), at: .beginning)

            app.on(.post, "echo", body: .stream) { request -> Response in
                // The route reads the same body the middleware already read, and streams it back.
                let payload = request.body.data.map { Data($0.readableBytesView) } ?? Data()
                var response = Response(body: try .init(stream: { writer in
                    // Several chunks, so the response really is streamed rather than written once.
                    for start in stride(from: 0, to: payload.count, by: 4096) {
                        try await writer.write(payload[start..<min(start + 4096, payload.count)])
                    }
                }, count: payload.count))
                response.headers.contentType = .binary
                return response
            }

            // Larger than the ~2000 bytes the issue said was enough to trigger the crash.
            let sent = Data(String(repeating: "x", count: 100_000).utf8)

            try await app.test(method: .running()) { runner in
                var headers = HTTPFields()
                headers.contentType = .plainText
                let res = try await runner.sendRequest(
                    .post, "/echo", headers: headers, body: ByteBuffer(bytes: sent))

                #expect(res.status == .ok)
                #expect(seen.withLockedValue { $0 } == sent.count, "middleware did not see the whole body")
                #expect(try await res.body.data() == sent)

                // The connection survives: a second request over it is served normally.
                let again = try await runner.sendRequest(
                    .post, "/echo", headers: headers, body: ByteBuffer(bytes: sent))
                #expect(again.status == .ok)
                #expect(try await again.body.data() == sent)
            }
        }
    }

    @Test("collect() gathers a streaming body into a single buffer")
    func testCollectStreamingBody() async throws {
        var body = Response.Body(stream: { writer in
            try await writer.write("Hello, ")
            try await writer.write("collected!")
        })
        let collected = try await body.collect()
        #expect(collected.map { String(decoding: $0, as: UTF8.self) } == "Hello, collected!")
    }

    @Test("Every ResponseBodyWriter overload reaches the stream")
    func testWriterOverloads() async throws {
        var body = Response.Body(stream: { writer in
            // String
            try await writer.write("a")
            // some Sequence<UInt8>
            try await writer.write([UInt8]([0x62]))
            // Data, via the same Sequence overload
            try await writer.write(Data("c".utf8))
            // Span<UInt8>
            let d: [UInt8] = [0x64]
            try await writer.write(d.span)
            // RawSpan - the protocol requirement itself
            let e: [UInt8] = [0x65]
            try await writer.write(e.span.bytes)
            // A sequence of chunks
            try await writer.write(contentsOf: [[UInt8]([0x66]), [UInt8]([0x67])])
        })
        let collected = try await body.collect()
        #expect(collected.map { String(decoding: $0, as: UTF8.self) } == "abcdefg")
    }

    @Test("withStreamingBytes delivers a streaming body chunk by chunk")
    func testWithStreamingBytesOnStream() async throws {
        let chunks = NIOLockedValueBox([String]())
        let body = Response.Body(stream: { writer in
            try await writer.write("alpha")
            try await writer.write("beta")
            try await writer.write("gamma")
        })
        try await body.withStreamingBytes { span in
            var bytes = [UInt8]()
            for i in 0..<span.byteCount { bytes.append(unsafe span.unsafeLoad(fromByteOffset: i, as: UInt8.self)) }
            chunks.withLockedValue { $0.append(String(decoding: bytes, as: UTF8.self)) }
        }
        // Delivered separately and in order - not collected into one blob.
        #expect(chunks.withLockedValue { $0 } == ["alpha", "beta", "gamma"])
    }

    @Test("withStreamingBytes hands a buffered body over as a single chunk")
    func testWithStreamingBytesOnBuffered() async throws {
        for body in [Response.Body(string: "hello"), Response.Body(data: Data("hello".utf8))] {
            let chunks = NIOLockedValueBox([String]())
            try await body.withStreamingBytes { span in
                var bytes = [UInt8]()
                for i in 0..<span.byteCount { bytes.append(unsafe span.unsafeLoad(fromByteOffset: i, as: UInt8.self)) }
                chunks.withLockedValue { $0.append(String(decoding: bytes, as: UTF8.self)) }
            }
            #expect(chunks.withLockedValue { $0 } == ["hello"])
        }
    }

    @Test("withStreamingBytes does not call the closure for an empty body")
    func testWithStreamingBytesOnEmpty() async throws {
        let calls = NIOLockedValueBox(0)
        try await Response.Body().withStreamingBytes { _ in
            calls.withLockedValue { $0 += 1 }
        }
        #expect(calls.withLockedValue { $0 } == 0)
    }

    @Test("withStreamingBytes propagates an error thrown mid-stream")
    func testWithStreamingBytesPropagatesError() async throws {
        let seen = NIOLockedValueBox(0)
        let body = Response.Body(stream: { writer in
            try await writer.write("first")
            throw MidStreamError()
        })
        await #expect(throws: MidStreamError.self) {
            try await body.withStreamingBytes { _ in
                seen.withLockedValue { $0 += 1 }
            }
        }
        // The closure saw the chunk that was written before the throw.
        #expect(seen.withLockedValue { $0 } == 1)
    }

    @Test("reduceBytes folds a streaming body chunk by chunk")
    func testReduceBytesOnStream() async throws {
        let body = Response.Body(stream: { writer in
            try await writer.write("alpha")
            try await writer.write("beta")
            try await writer.write("gamma")
        })
        // Chunk sizes prove the fold sees each chunk separately rather than one blob.
        let sizes = try await body.reduceBytes(into: [Int]()) { acc, span in
            acc.append(span.byteCount)
        }
        #expect(sizes == [5, 4, 5])
    }

    @Test("reduceBytes folds a buffered body in a single step")
    func testReduceBytesOnBuffered() async throws {
        let total = try await Response.Body(string: "hello").reduceBytes(into: 0) { acc, span in
            acc += span.byteCount
        }
        #expect(total == 5)
    }

    @Test("reduceBytes returns the initial value for an empty body")
    func testReduceBytesOnEmpty() async throws {
        let total = try await Response.Body().reduceBytes(into: 42) { acc, span in
            acc += span.byteCount
        }
        #expect(total == 42)
    }

    @Test("reduceBytes hashes a streaming body without buffering it")
    func testReduceBytesHashing() async throws {
        let chunks = ["alpha", "beta", "gamma"]
        let body = Response.Body(stream: { writer in
            for chunk in chunks { try await writer.write(chunk) }
        })
        let streamed = try await body.reduceBytes(into: SHA256()) { hasher, span in
            span.withUnsafeBytes { unsafe hasher.update(bufferPointer: $0) }
        }.finalize()
        // Same digest as hashing the whole thing at once.
        let expected = SHA256.hash(data: Data(chunks.joined().utf8))
        #expect(Array(streamed) == Array(expected))
    }

    @Test("collect() caches, so the stream closure runs only once")
    func testCollectCachesStream() async throws {
        let runs = NIOLockedValueBox(0)
        var body = Response.Body(stream: { writer in
            runs.withLockedValue { $0 += 1 }
            try await writer.write("payload")
        })
        let first = try await body.collect()
        let second = try await body.collect()
        #expect(first.map { String(decoding: $0, as: UTF8.self) } == "payload")
        #expect(second.map { String(decoding: $0, as: UTF8.self) } == "payload")
        #expect(runs.withLockedValue { $0 } == 1)
    }

    @Test("collect() replaces a stream with an in-memory body for anything downstream")
    func testCollectReplacesStreamStorage() async throws {
        // Exactly the middleware case: read the body, then hand the response on. A stream backed by
        // a source that can only be drained once used to silently send nothing after this point.
        let (chunks, continuation) = AsyncStream<String>.makeStream()
        continuation.yield("alpha")
        continuation.yield("beta")
        continuation.finish()

        var response = Response(status: .ok, body: .init(stream: { writer in
            for await chunk in chunks { try await writer.write(chunk) }
        }))
        let collected = try await response.body.collect()
        #expect(collected.map { String(decoding: $0, as: UTF8.self) } == "alphabeta")

        // The response now carries the bytes, not the drained stream, so a second reader sees them.
        #expect(response.body.string == "alphabeta")
        #expect(response.body.count == 9)
        var again = response.body
        try #expect(await again.collect().map { String(decoding: $0, as: UTF8.self) } == "alphabeta")
    }

    @Test("A stream read with withStreamingBytes cannot be read a second time")
    func testStreamedBodyCannotBeReadTwice() async throws {
        let runs = NIOLockedValueBox(0)
        let body = Response.Body(stream: { writer in
            runs.withLockedValue { $0 += 1 }
            try await writer.write("once")
        })
        #expect(body.isUnconsumedStream)

        // Streaming hands the bytes to the caller and keeps nothing.
        let seen = NIOLockedValueBox(0)
        try await body.withStreamingBytes { span in
            let count = span.byteCount
            seen.withLockedValue { $0 += count }
        }
        #expect(seen.withLockedValue { $0 } == 4)
        #expect(!body.isUnconsumedStream)
        #expect(body.string == nil)

        // So there is nothing left for a second reader, streaming or collecting, through any copy.
        // A clear error, not a second run of the callback: a network-backed source can't be
        // iterated twice, and a generator running again would hide that it had.
        await #expect(throws: Response.Body.AlreadyConsumedError.self) {
            try await body.withStreamingBytes { _ in }
        }
        var copy = body
        await #expect(throws: Response.Body.AlreadyConsumedError.self) {
            _ = try await copy.collect()
        }
        #expect(runs.withLockedValue { $0 } == 1)
    }

    @Test("Collecting through one copy of a body is visible from the others")
    func testCollectSharesBytesAcrossCopies() async throws {
        // A `ContentContainer` reached through a computed `content` property holds a *copy* of the
        // body, so its collection cannot be written back. Without state shared between copies that
        // would drain the stream and leave the original pointing at a spent source.
        let runs = NIOLockedValueBox(0)
        let original = Response.Body(stream: { writer in
            runs.withLockedValue { $0 += 1 }
            try await writer.write("shared")
        })

        var copy = original
        try #expect(await copy.collect().map { String(decoding: $0, as: UTF8.self) } == "shared")

        // The original still holds `.stream`, but the bytes are reachable without re-running it.
        #expect(original.string == "shared")
        #expect(original.data.map { String(decoding: $0, as: UTF8.self) } == "shared")
        #expect(original.count == 6)

        var second = original
        try #expect(await second.collect().map { String(decoding: $0, as: UTF8.self) } == "shared")
        #expect(runs.withLockedValue { $0 } == 1)
    }

    @Test("An unknown-length stream reports its real count once collected")
    func testCollectedStreamReportsRealCount() async throws {
        let body = Response.Body(stream: { writer in try await writer.write("twelve bytes") })
        // `nil` until collected: an unknown-length stream cannot say how long it is in advance.
        #expect(body.count == nil)
        var copy = body
        _ = try await copy.collect()
        #expect(body.count == 12)
    }

    @Test("collect(max:) rejects a stream that produces more than the limit")
    func testCollectMaxRejectsOversizedStream() async throws {
        var body = Response.Body(stream: { writer in
            for _ in 0..<10 { try await writer.write(String(repeating: "x", count: 100)) }
        })
        await #expect(throws: Abort.self) { try await body.collect(max: 256) }
    }

    @Test("collect(max:) allows a stream that stays within the limit")
    func testCollectMaxAllowsStreamWithinLimit() async throws {
        var body = Response.Body(stream: { writer in try await writer.write("small") })
        try #expect(await body.collect(max: 256).map { String(decoding: $0, as: UTF8.self) } == "small")
    }

    @Test("collect(max:) rejects a declared length over the limit without running the stream")
    func testCollectMaxRejectsDeclaredLengthBeforeRunning() async throws {
        let ran = NIOLockedValueBox(false)
        var body = try Response.Body(stream: { writer in
            ran.withLockedValue { $0 = true }
            try await writer.write(String(repeating: "x", count: 1000))
        }, count: 1000)
        await #expect(throws: Abort.self) { try await body.collect(max: 256) }
        #expect(ran.withLockedValue { $0 } == false)
    }

    @Test("Streaming a body a copy already collected replays the bytes instead of re-running it")
    func testStreamingAfterCollectReplaysFromCache() async throws {
        // A one-shot source - an `AsyncStream`, a file handle, a client response's iterator - yields
        // nothing on a second run, so re-running the callback here would silently produce an empty
        // body rather than an error.
        let runs = NIOLockedValueBox(0)
        let (chunks, continuation) = AsyncStream<String>.makeStream()
        continuation.yield("payload")
        continuation.finish()

        let original = Response.Body(stream: { writer in
            runs.withLockedValue { $0 += 1 }
            for await chunk in chunks { try await writer.write(chunk) }
        })

        var copy = original
        _ = try await copy.collect()

        var seen = ""
        try await original.withStreamingBytes { span in
            seen += String(decoding: span.withUnsafeBytes { unsafe Array($0) }, as: UTF8.self)
        }
        #expect(seen == "payload")
        #expect(runs.withLockedValue { $0 } == 1)

        // `reduceBytes` is built on `withStreamingBytes`, so it replays too.
        let count = try await original.reduceBytes(into: 0) { total, span in total += span.byteCount }
        #expect(count == 7)
        #expect(runs.withLockedValue { $0 } == 1)
    }

    @Test("The server writes the collected bytes for a body drained through a copy", .timeLimit(.minutes(1)))
    func testServerSerialisesBodyCollectedThroughACopy() async throws {
        // Exactly what a middleware calling `content.decode` does: the container holds a copy, so the
        // response still carries `.stream` storage over a source that has already been drained.
        try await withApp { app in
            app.get("proxied") { _ -> Response in
                let (chunks, continuation) = AsyncStream<String>.makeStream()
                continuation.yield("hello ")
                continuation.yield("world")
                continuation.finish()

                let response = Response(status: .ok, body: .init(stream: { writer in
                    for await chunk in chunks { try await writer.write(chunk) }
                }))
                var copy = response.body
                _ = try await copy.collect()
                return response
            }

            try await app.testing(method: .running()).test(.get, "/proxied") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "hello world")
            }
        }
    }

    @Test("data(max:) and string(max:) collect a stream without needing a var")
    func testCollectingAccessorsWorkOnALet() async throws {
        let runs = NIOLockedValueBox(0)
        let (chunks, continuation) = AsyncStream<String>.makeStream()
        continuation.yield("hello ")
        continuation.yield("world")
        continuation.finish()

        // `let`, deliberately: the plain properties cannot collect, so these have to.
        let body = Response.Body(stream: { writer in
            runs.withLockedValue { $0 += 1 }
            for await chunk in chunks { try await writer.write(chunk) }
        })

        #expect(body.string == nil)
        #expect(body.data == nil)
        #expect(body.count == nil)

        try #expect(await body.string() == "hello world")

        // Collecting through the accessor's copy still fills the shared cache, so the plain
        // properties answer afterwards and the stream is never run a second time.
        #expect(body.string == "hello world")
        #expect(body.data.map { String(decoding: $0, as: UTF8.self) } == "hello world")
        #expect(body.count == 11)
        try #expect(await body.data().map { String(decoding: $0, as: UTF8.self) } == "hello world")
        #expect(runs.withLockedValue { $0 } == 1)
    }

    @Test("The collecting accessors honour their limit")
    func testCollectingAccessorsHonourMax() async throws {
        // A failed collect still consumes the stream, so each accessor is tried on a fresh body.
        func makeBody() -> Response.Body {
            Response.Body(stream: { writer in
                try await writer.write(String(repeating: "x", count: 1000))
            })
        }
        await #expect(throws: Abort.self) { try await makeBody().string(max: 256) }
        await #expect(throws: Abort.self) { try await makeBody().data(max: 256) }
    }

    @Test("The collecting accessors pass a buffered body straight through")
    func testCollectingAccessorsOnBufferedBodies() async throws {
        try #expect(await Response.Body(string: "plain").string() == "plain")
        try #expect(await Response.Body(staticString: "static").string() == "static")
        try #expect(await Response.Body(data: Data("bytes".utf8)).string() == "bytes")
        try #expect(await Response.Body.empty.string() == nil)
        try #expect(await Response.Body.empty.data() == nil)
    }

    @Test("The test client hands back a streaming body and reads it on demand", .timeLimit(.minutes(1)))
    func testTesterResponseBodyIsLazy() async throws {
        try await withApp { app in
            app.get("stream") { _ in
                Response(body: .init(stream: { writer in
                    try await writer.write("alpha")
                    try await writer.write("beta")
                }))
            }

            try await app.testing(.running) { client in
                // Nothing is buffered until something asks for it.
                let response = try await client.get("/stream")
                #expect(response.body.string == nil)
                #expect(response.body.count == nil)

                // Asking collects, and every copy of the body then sees the same bytes.
                let copy = response.body
                try #expect(await response.body.requireString() == "alphabeta")
                #expect(copy.string == "alphabeta")
                #expect(copy.count == 9)
            }
        }
    }

    @Test("A streaming body rejects a negative declared length")
    func testNegativeStreamCountIsRejected() async throws {
        // Thrown, not trapped: a `precondition` here would be checked in release builds too, so one
        // handler's arithmetic mistake would take down a server serving everything else correctly.
        #expect(throws: Response.Body.NegativeCountError(count: -5)) {
            try Response.Body(stream: { _ in }, count: -5)
        }

        // `nil` is the way to say "length unknown", and zero is a legitimate length.
        #expect(throws: Never.self) {
            _ = try Response.Body(stream: { _ in }, count: 0)
            _ = try Response.Body(stream: { _ in }, count: nil)
        }
        _ = Response.Body(stream: { _ in })   // the convenience cannot fail, so it does not throw

        // It surfaces as a 500 with a diagnosable reason rather than an opaque failure.
        let error = Response.Body.NegativeCountError(count: -5)
        #expect(error.status == .internalServerError)
        #expect(error.reason.contains("-5"))
    }

    @Test("An empty write does not corrupt the stream")
    func testEmptyWrite() async throws {
        var body = Response.Body(stream: { writer in
            try await writer.write("")
            try await writer.write([UInt8]())
            try await writer.write("done")
        })
        let collected = try await body.collect()
        #expect(collected.map { String(decoding: $0, as: UTF8.self) } == "done")
    }

    @Test("Server does not write a body for a status that cannot carry one", .timeLimit(.minutes(1)),
          .bug("https://github.com/swift-server/swift-http-server/issues/118"))
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
                #expect(!noContent.contains("Hello, world!"), "\(noContent.debugDescription)")

                let notModified = try await rawExchange(port: port, path: "/not-modified").bytes
                #expect(notModified.hasPrefix("HTTP/1.1 304 Not Modified"))
                #expect(!notModified.contains("Hello, world!"), "\(notModified.debugDescription)")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server closes the connection when the client asks for Connection: close", .timeLimit(.minutes(1)),
          .bug("https://github.com/swift-server/swift-http-server/issues/119"))
    func testConnectionCloseIsHonoured() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("hello") { _ in "hi" }

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

                let exchange = try await rawExchange(
                    port: port,
                    path: "/hello",
                    extraHeaders: "Connection: close\r\n")
                #expect(exchange.bytes.contains("hi"))

                // RFC 9112 § 9.6: a server that receives `Connection: close` must close the
                // connection once the response is sent, and should echo the header back. Today the
                // connection is left open until the 30s read-header timeout reaps it.
                #warning("swift-http-server#119: the request's `Connection` header is never read, so `Connection: close` is ignored — drop this `withKnownIssue` when the upstream fix lands")
                withKnownIssue("the connection is left open after the response") {
                    #expect(exchange.serverClosed)
                    #expect(exchange.bytes.lowercased().contains("connection: close"))
                }

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server survives a client aborting mid-file-stream",
          .bug("https://github.com/swift-server/swift-http-server/issues/53"))
    func testClientAbortMidFileStreamDoesNotBreakServer() async throws {
        // Big enough that the server is still reading when the client gives up: the transport
        // can't have buffered the whole thing, so the body closure is mid-read when it's cancelled.
        let filePath = try await makeTemporaryFile(size: 8 << 20)

        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("file") { req -> Response in
                try await app.fileio.streamFile(at: filePath, for: req, advancedETagComparison: false)
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

                // Abort mid-stream: collect with a tiny limit so the client drops the connection
                // while the file is still being read. The writes then fail with an I/O error rather
                // than cancelling the task, so this covers the error path out of the body closure;
                // the cancellation path is covered by `testCancelledFileStreamClosesHandle`.
                await #expect(throws: (any Error).self) {
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/file"), timeout: .seconds(10)
                    )
                    _ = try await resp.body.collect(upTo: 16)
                }

                // The server must still be alive and serving.
                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/ok"), timeout: .seconds(10)
                )
                #expect(ok.status == .ok)
                try #expect(await ok.body.collect(upTo: 1 << 20).string == "ok")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server does not crash when a handler returns an informational status")
    func testInformationalStatusDoesNotCrashServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            // A 1xx can only precede a final response. The server trapped on one before Vapor
            // started rejecting it, so this is really a "the process is still alive" test.
            app.get("informational") { _ in Response(status: .continue) }
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

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/informational"), timeout: .seconds(15))
                #expect(resp.status == .internalServerError)

                let ok = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/ok"), timeout: .seconds(15))
                #expect(ok.status == .ok)

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Response body stream completion runs once when the client disconnects",
          .bug("https://github.com/vapor/vapor/issues/3002"))
    func testStreamCompletionRunsOnceOnClientDisconnect() async throws {
        // The Vapor 4 shape of this bug: the body-stream closure wrote `.end`/`.error` itself while
        // the server concluded the same response, so a connection failure ran the completion twice.
        // `ResponseBodyWriter` can only write buffers now — concluding is the server's job — so the
        // race has nowhere to happen, and this pins that down.
        let filePath = try await makeTemporaryFile(size: 8 << 20)

        let completions = NIOLockedValueBox(0)

        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("file") { req -> Response in
                try await app.fileio.streamFile(at: filePath, for: req, advancedETagComparison: false) { _ in
                    completions.withLockedValue { $0 += 1 }
                }
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
                    let resp = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/file"), timeout: .seconds(10)
                    )
                    _ = try await resp.body.collect(upTo: 16)
                }

                // The server unwinds the aborted response on its own schedule, so wait for the
                // completion rather than assuming it has already run...
                for _ in 0..<200 where completions.withLockedValue({ $0 }) == 0 {
                    try await Task.sleep(for: .milliseconds(10))
                }
                // ...then give a second call a chance to land before declaring there wasn't one.
                try await Task.sleep(for: .milliseconds(200))
                #expect(completions.withLockedValue { $0 } == 1)

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }
}
