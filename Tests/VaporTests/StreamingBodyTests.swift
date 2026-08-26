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
                    let chunk = [UInt8](repeating: 0x41, count: chunkSize)
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

    @Test("Server survives a stream that writes fewer bytes than its declared length",
          .bug("https://github.com/swift-server/swift-http-server/issues/116"))
    func testBadStreamLengthDoesNotBreakServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            // Declares `Content-Length: 2` (via `count`) but only writes a single byte.
            app.get("bad-length") { _ -> Response in
                Response(status: .ok, body: .init(stream: { writer in
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
                #expect(try await ok.body.collect(upTo: 1 << 20).string == "ok")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("collect() gathers a streaming body into a single buffer")
    func testCollectStreamingBody() async throws {
        let body = Response.Body(stream: { writer in
            try await writer.write("Hello, ")
            try await writer.write("collected!")
        })
        let collected = try await body.collect()
        #expect(collected.map { String(decoding: $0, as: UTF8.self) } == "Hello, collected!")
    }

    @Test("Every ResponseBodyWriter overload reaches the stream")
    func testWriterOverloads() async throws {
        let body = Response.Body(stream: { writer in
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

    @Test("An empty write does not corrupt the stream")
    func testEmptyWrite() async throws {
        let body = Response.Body(stream: { writer in
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
                try await req.fileio.streamFile(at: filePath, advancedETagComparison: false)
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
                #expect(try await ok.body.collect(upTo: 1 << 20).string == "ok")

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
                try await req.fileio.streamFile(at: filePath, advancedETagComparison: false) { _ in
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
