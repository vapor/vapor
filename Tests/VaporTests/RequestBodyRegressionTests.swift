import AsyncHTTPClient
import HTTPTypes
import InMemoryLogging
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import RoutingKit
import Synchronization
import Testing
import Vapor
import VaporTesting

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Regressions for reported request-body bugs, one test per issue.
@Suite("Request Body Regressions")
struct RequestBodyRegressionTests {
    struct Payload: Content, Equatable { var value: String? }

    @Test("A second concurrent collect fails instead of returning an empty body", .bug("https://github.com/vapor/vapor/issues/3271"))
    func concurrentCollectDoesNotTruncate() async throws {
        try await withApp { app in
            app.on(.post, "collect", maxBodySize: "1mb") { req -> String in
                let outcomes = await withTaskGroup(of: Result<Int, any Error>.self) { group in
                    for _ in 0..<2 {
                        group.addTask {
                            do { return .success(try await req.body.data()?.count ?? -1) } catch { return .failure(error) }
                        }
                    }
                    return await group.reduce(into: [Result<Int, any Error>]()) { $0.append($1) }
                }
                let sizes = outcomes.compactMap { try? $0.get() }
                // The invariant is not *which* of the two wins — if the first finishes before the
                // second starts, the second legitimately gets the cached body — but that neither is
                // ever handed a short one.
                let short = sizes.filter { $0 != 4096 }.count
                return "results=\(outcomes.count) short=\(short)"
            }
            try await app.testing(.running) { client in
                let res = try await client.post("collect") {
                    $0.body = .init(data: Data(repeating: 0x41, count: 4096))
                }
                // Both collectors accounted for, and neither was handed a truncated body: each
                // either got all 4096 bytes or was refused outright.
                try #expect(await res.body.requireString() == "results=2 short=0")
            }
        }
    }

    @Test("A middleware decoding the body does not consume it from the handler", .bug("https://github.com/vapor/vapor/issues/2742"))
    func middlewareDecodeLeavesBodyIntact() async throws {
        struct Peek: Middleware {
            func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                _ = try? await request.content.decode(Payload.self)
                return try await next.respond(to: request)
            }
        }
        try await withApp { app in
            app.grouped(Peek()).post("m") { req -> String in
                try await req.content.decode(Payload.self).value ?? "<nil>"
            }
            try await app.testing(.running) { client in
                var seen = Set<String>()
                for _ in 0..<40 {
                    let res = try await client.post("m", headers: [.contentType: "application/json"]) {
                        $0.body = .init(data: Data(#"{"value":"hello"}"#.utf8))
                    }
                    seen.insert("\(res.status.code):\(try await res.body.requireString())")
                }
                #expect(seen == ["200:hello"])
            }
        }
    }

    @Test("Erroring mid-stream does not strand the connection", .timeLimit(.minutes(1)), .bug("https://github.com/vapor/vapor/issues/3005"))
    func errorMidStreamDoesNotLeak() async throws {
        struct Boom: Error {}
        try await withApp { app in
            app.on(.post, "error") { req -> String in
                _ = try await req.body.withReader { reader in
                    try await reader.read { span, _ in span.count }
                }
                throw Boom()
            }
            app.get("ok") { _ in "ok" }
            try await withRunningServer(app) { port in
                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/error")
                request.method = .POST
                request.body = .bytes(ByteBuffer(repeating: 0x41, count: 256))
                let errored = try await HTTPClient.shared.execute(request, timeout: .seconds(10))
                #expect(errored.status.code == 500)

                let after = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/ok"), timeout: .seconds(10))
                #expect(after.status.code == 200)
            }
        }
    }

    @Test("A large buffered POST body arrives whole", .bug("https://github.com/vapor/vapor/issues/2682"))
    func largeBufferedPostArrivesWhole() async throws {
        try await withApp { app in
            app.on(.post, "big", maxBodySize: "10mb") { req -> String in
                "\(try await req.body.data()?.count ?? -1)"
            }
            try await app.testing(.running) { client in
                for size in [2047, 2048, 2049, 65_536, 1_000_000] {
                    let res = try await client.post("big") {
                        $0.body = .init(data: Data(repeating: 0x41, count: size))
                    }
                    try #expect(await res.body.requireString() == "\(size)")
                }
            }
        }
    }

    @Test(
        "Chunks are delivered one at a time, never overlapping", .bug("https://github.com/vapor/vapor/issues/2564"),
        .bug("https://github.com/vapor/vapor/issues/2565"))
    func chunksNeverOverlap() async throws {
        try await withApp { app in
            app.on(.post, "sequence") { req -> String in
                let overlapping = Mutex(false)
                let inCallback = Mutex(false)
                var chunks = 0
                try await req.body.forEachChunk { _ in
                    if inCallback.withLock({ $0 }) { overlapping.withLock { $0 = true } }
                    inCallback.withLock { $0 = true }
                    try await Task.sleep(for: .milliseconds(1))
                    inCallback.withLock { $0 = false }
                    chunks += 1
                }
                return "chunks=\(chunks) overlapping=\(overlapping.withLock { $0 })"
            }
            try await app.testing(.running) { client in
                let res = try await client.post("sequence") { req in
                    req.body = .init(stream: { writer in
                        for _ in 0..<8 { try await writer.write(Data(repeating: 0x41, count: 1024)) }
                    })
                }
                let body = try await res.body.requireString()
                // More than one chunk, so the loop really ran, and no two overlapped.
                #expect(body.hasSuffix("overlapping=false"))
                #expect(body != "chunks=1 overlapping=false")
            }
        }
    }

    @Test("An empty URL-encoded form decodes rather than failing", .bug("https://github.com/vapor/vapor/issues/3032"))
    func emptyFormDecodes() async throws {
        try await withApp { app in
            app.post("form") { req -> String in
                let payload = try await req.content.decode(Payload.self)
                return "value=\(payload.value ?? "nil")"
            }
            try await app.testing(.running) { client in
                let res = try await client.post("form", headers: [.contentType: "application/x-www-form-urlencoded"])
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "value=nil")
            }
        }
    }

    /// A terminal read is allowed to carry a final batch of bytes alongside the end flag —
    /// `AsyncReader`'s contract says the caller must process both. `forEachChunk` used to check the
    /// flag first and drop them. Vapor's own server never sends bytes that way, so this needs a
    /// conformance that does; `RequestBodyReader` is public, so third-party ones can.
    @Test("A terminal chunk's bytes are delivered, not dropped")
    func terminalChunkBytesAreDelivered() async throws {
        struct TerminalBytesReader: RequestBodyReader, ~Escapable {
            final class State { var delivered = false }
            let state: State

            @_lifetime(immortal)
            init(state: State) { self.state = state }

            func read<R>(_ body: (Span<UInt8>, Bool) async throws -> R) async throws -> R {
                // Bytes and the end flag together, on the same read.
                let bytes: [UInt8] = self.state.delivered ? [] : Array("TAIL".utf8)
                self.state.delivered = true
                return try await body(bytes.span, true)
            }
        }

        var seen = ""
        let reader = TerminalBytesReader(state: .init())
        try await reader.forEachChunk { span in
            seen += String(decoding: span.withUnsafeBufferPointer { unsafe Array($0) }, as: UTF8.self)
        }
        #expect(seen == "TAIL")
    }

    /// A read that fails at the transport used to latch nothing, so the next read reported a clean
    /// end-of-body on a body that was actually cut short. The failure is sticky now.
    @Test("A transport failure is sticky, not reported as a clean end", .timeLimit(.minutes(1)))
    func transportFailureIsSticky() async throws {
        // The connection is gone by the time the handler notices, so the verdict comes back through
        // a side channel rather than a response.
        let verdict = Mutex("never ran")
        // The handler is about to block on the body, so the client can hang up.
        let reading = Checkpoint()
        // The handler has recorded its verdict.
        let decided = Checkpoint()
        try await withApp { app in
            app.on(.post, "cut") { req -> String in
                defer { decided.reach() }
                do {
                    reading.reach()
                    _ = try await req.body.data()
                    verdict.withLock { $0 = "collected" }
                } catch {
                    // The transport failed part-way. Asking again must say so rather than hand back
                    // an empty body as though the request had simply ended.
                    do {
                        let second = try await req.body.data()
                        verdict.withLock { $0 = "second read returned \(second?.count ?? -1) bytes" }
                    } catch is RequestBodyReadFailed {
                        verdict.withLock { $0 = "sticky" }
                    } catch {
                        verdict.withLock { $0 = "second read threw \(type(of: error))" }
                    }
                    // Rethrow rather than answering. The peer is gone, so a response here races the
                    // server's own teardown of a request whose body never completed.
                    throw error
                }
                return "done"
            }
            try await withRunningServer(app) { port in
                // Promise 100 bytes, send 10, and hang up once the handler is waiting for the rest.
                // Hanging up on a timer instead meant guessing how long dispatch takes, and a loaded
                // machine outlasted the guess: the client gave up before the handler had even run.
                let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                    .connect(host: "127.0.0.1", port: port) { channel in
                        channel.eventLoop.makeCompletedFuture {
                            try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                        }
                    }
                try await channel.executeThenClose { _, outbound in
                    try await outbound.write(
                        ByteBuffer(
                            string: "POST /cut HTTP/1.1\r\nHost: localhost\r\nContent-Length: 100\r\n\r\n0123456789"))
                    await reading.wait()
                }
                // The handler notices the hang-up on its own schedule. Wait for its verdict while
                // the server is still up, or the assertion below races the teardown.
                await decided.wait()
            }
        }
        #expect(verdict.withLock { $0 } == "sticky")
    }

    /// A client that promises a body and hangs up part-way surfaced NIO's parser error to the error
    /// middleware, which reported it as a warning. Nothing the application can do about a truncated
    /// upload, and any client can send one, so it now reports at debug.
    @Test(
        "A truncated upload reports at debug, not as a warning",
        .bug("https://github.com/vapor/vapor/issues/3203"), .timeLimit(.minutes(1)))
    func truncatedUploadReportsAtDebug() async throws {
        /// Sits outside the error middleware, so reaching it means the error has been reported.
        struct ReportedMiddleware: Middleware {
            let reported: Checkpoint
            func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                defer { self.reported.reach() }
                return try await next.respond(to: request)
            }
        }

        let logHandler = InMemoryLogHandler()
        var logger = Logger(label: "codes.vapor.test", factory: { _ in logHandler })
        logger.logLevel = .debug
        let thrown = Mutex("never ran")
        // The handler is about to block on the body, so the client can hang up.
        let reading = Checkpoint()
        let reported = Checkpoint()
        try await withApp(logger: logger) { app in
            app.middleware.use(ReportedMiddleware(reported: reported), at: .beginning)
            app.on(.post, "cut") { req -> String in
                do {
                    reading.reach()
                    _ = try await req.body.data()
                    thrown.withLock { $0 = "nothing" }
                } catch {
                    thrown.withLock { $0 = "\(type(of: error))" }
                    throw error
                }
                return "done"
            }
            try await withRunningServer(app) { port in
                let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                    .connect(host: "127.0.0.1", port: port) { channel in
                        channel.eventLoop.makeCompletedFuture {
                            try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                        }
                    }
                try await channel.executeThenClose { _, outbound in
                    try await outbound.write(
                        ByteBuffer(
                            string: "POST /cut HTTP/1.1\r\nHost: localhost\r\nContent-Length: 100\r\n\r\nthis is just 21 bytes"))
                    await reading.wait()
                }
                await reported.wait()
            }
        }
        #expect(thrown.withLock { $0 } == "RequestBodyTransportFailed")
        let reports = logHandler.entries.filter { "\($0.message)".contains("The request body could not be read") }
        #expect(reports.map(\.level) == [.debug])
        let loud = logHandler.entries.filter { $0.level >= .warning }.map { "\($0.level): \($0.message)" }
        #expect(loud.isEmpty)
    }

    /// Metrics record the request body size after the responder chain has run. With lazy bodies the
    /// size has to come from a counter on the stream, because nothing has necessarily cached it.
    @Test("The recorded body size counts what was actually read")
    func metricsCountBytesRead() async throws {
        try await withApp { app in
            app.on(.post, "sized", maxBodySize: "1mb") { req -> String in
                "\(try await req.body.data()?.count ?? -1)"
            }
            try await app.testing(.running) { client in
                let res = try await client.post("sized") {
                    $0.body = .init(data: Data(repeating: 0x41, count: 2048))
                }
                try #expect(await res.body.requireString() == "2048")
            }
        }
    }
}
