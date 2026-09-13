import Vapor
import VaporTesting
import Testing
import NIOCore
import HTTPTypes
import RoutingKit
import Synchronization
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("Client Streaming Tests")
struct ClientStreamingTests {
    struct Boom: Error {}

    // MARK: - The handoff itself

    @Test("send does not return until the consumer takes the chunk")
    func testHandoffIsBackpressured() async throws {
        let handoff = ChunkHandoff()
        let sent = Mutex(false)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await handoff.send(ByteBuffer(string: "one"))
                sent.withLock { $0 = true }
            }
            // Give the producer every chance to run ahead. With a buffer it would; with a handoff
            // it parks, because nothing has taken the chunk yet.
            for _ in 0..<50 { await Task.yield() }
            #expect(sent.withLock { $0 } == false, "send returned before the chunk was taken")

            var iterator = ChunkHandoffSequence(handoff: handoff).makeAsyncIterator()
            let chunk = try? await iterator.next()
            #expect(chunk.map { String(buffer: $0) } == "one")
            handoff.finish()
            await group.waitForAll()
        }
        #expect(sent.withLock { $0 })
    }

    @Test("A producer error surfaces on the consuming side")
    func testHandoffPropagatesFailure() async throws {
        let handoff = ChunkHandoff()
        handoff.finish(throwing: Boom())
        var iterator = ChunkHandoffSequence(handoff: handoff).makeAsyncIterator()
        await #expect(throws: Boom.self) { try await iterator.next() }
    }

    @Test("Cancelling the producing task unparks a waiting send")
    func testHandoffCancellationUnparksProducer() async throws {
        let handoff = ChunkHandoff()
        let task = Task { try await handoff.send(ByteBuffer(string: "stuck")) }
        for _ in 0..<50 { await Task.yield() }
        task.cancel()
        await #expect(throws: (any Error).self) { try await task.value }
    }

    // MARK: - End to end

    @Test("A streamed client body arrives at the route whole")
    func testStreamedBodyReachesRoute() async throws {
        try await withApp { app in
            app.on(.post, "upload", maxBodySize: "1mb") { req -> String in
                "\(try await req.body.data()?.count ?? 0)"
            }
            try await app.testing(.running) { client in
                let res = try await client.post("upload") { req in
                    req.body = .init(stream: { writer in
                        for _ in 0..<64 {
                            try await writer.write(Data(repeating: 0x41, count: 1024))
                        }
                    })
                }
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "65536")
            }
        }
    }

    @Test("A streamed body of unknown length is sent chunked")
    func testStreamedBodyIsChunkFramed() async throws {
        try await withApp { app in
            app.on(.post, "framing") { req -> String in
                let te = req.headers[.transferEncoding] ?? "-"
                let cl = req.headers[.contentLength] ?? "-"
                return "te=\(te) cl=\(cl)"
            }
            try await app.testing(.running) { client in
                // No declared count, so the client cannot send a Content-Length.
                let unknown = try await client.post("framing") { req in
                    req.body = .init(stream: { writer in try await writer.write("hello") })
                }
                try #expect(await unknown.body.requireString() == "te=chunked cl=-")

                // A declared count is framed with a length instead.
                let known = try await client.post("framing") { req in
                    req.body = try .init(stream: { writer in try await writer.write("hello") }, count: 5)
                }
                try #expect(await known.body.requireString() == "te=- cl=5")
            }
        }
    }

    @Test("An error thrown by the body closure fails the request")
    func testProducerErrorFailsRequest() async throws {
        try await withApp { app in
            app.on(.post, "upload") { _ -> String in "ok" }
            try await app.testing(.running) { client in
                await #expect(throws: (any Error).self) {
                    _ = try await client.post("upload") { req in
                        req.body = .init(stream: { writer in
                            try await writer.write("some")
                            throw Boom()
                        })
                    }
                }
            }
        }
    }

    @Test("A server that rejects mid-upload does not strand the producer", .timeLimit(.minutes(1)))
    func testEarlyRejectionWhileStreaming() async throws {
        try await withApp { app in
            app.routes.defaultMaxBodySize = 1024
            app.on(.post, "small") { req -> String in
                _ = try await req.body.data()
                return "ok"
            }
            try await app.testing(.running) { client in
                // The route answers 413 long before the body is finished, so the producer is left
                // parked with a chunk nobody will take. It has to be unparked, not left suspended.
                let outcome: String
                do {
                    let res = try await client.post("small") { req in
                        req.body = .init(stream: { writer in
                            for _ in 0..<512 {
                                try await writer.write(Data(repeating: 0x41, count: 1024))
                            }
                        })
                    }
                    outcome = "status \(res.status.code)"
                } catch {
                    // The connection closing under an in-flight upload is also a valid outcome here.
                    outcome = "threw"
                }
                #expect(outcome == "status 413" || outcome == "threw", "got \(outcome)")
            }
        }
    }

    @Test("The in-memory client collects a streamed body for the route")
    func testInMemoryClientCollectsStream() async throws {
        try await withApp { app in
            app.on(.post, "upload", maxBodySize: "1mb") { req -> String in
                "\(try await req.body.data()?.count ?? 0)"
            }
            // No wire to stream over, so the body is collected and handed over whole. The point is
            // that the same `ClientRequest.Body` works against either client.
            try await app.testing { client in
                let res = try await client.post("upload") { req in
                    req.body = .init(stream: { writer in
                        for _ in 0..<4 { try await writer.write(Data(repeating: 0x41, count: 16)) }
                    })
                }
                try #expect(await res.body.requireString() == "64")
            }
        }
    }
}
