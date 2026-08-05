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
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/buffered"), timeout: .seconds(10))
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
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/stream"), timeout: .seconds(10))
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == "Hello, streaming, world!")

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
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/stream"), timeout: .seconds(10))
                #expect(resp.status == .ok)
                let body = try await resp.body.collect(upTo: 1 << 20).string
                #expect(body == "Hello, legacy, world!")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }
}
