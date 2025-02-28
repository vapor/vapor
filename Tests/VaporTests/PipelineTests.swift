@testable import Vapor
import enum NIOHTTP1.HTTPParserError
import AsyncHTTPClient
import NIOEmbedded
import NIOCore
import NIOConcurrencyHelpers
import class NIOPosix.ClientBootstrap
import Testing
import VaporTesting

@Suite("Pipeline Tests")
struct PipelineTests {
    @Test("Test Echo Handlers")
    func echoHandlers() async throws {
        try await withApp { app in
            app.on(.post, "echo", body: .stream) { request -> Response in
                Response(body: .init(stream: { writer in
                    request.body.drain { body in
                        switch body {
                        case .buffer(let buffer):
                            return writer.write(.buffer(buffer))
                        case .error(let error):
                            return writer.write(.error(error))
                        case .end:
                            return writer.write(.end)
                        }
                    }
                }))
            }

            let asyncChannel = NIOAsyncTestingChannel()

            try await asyncChannel.testingEventLoop.flatSubmit {
                asyncChannel.pipeline.addVaporHTTP1Handlers(application: app, responder: app.responder, configuration: app.http.server.configuration)
            }.get()

            try await asyncChannel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\ntransfer-encoding: chunked\r\n\r\n1\r\na\r\n"))
            let chunk = try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string
            #expect(chunk?.contains("HTTP/1.1 200 OK") == true)
            #expect(chunk?.contains("connection: keep-alive") == true)
            #expect(chunk?.contains("transfer-encoding: chunked") == true)

            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "1\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "a")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)

            try await asyncChannel.writeInbound(ByteBuffer(string: "1\r\nb\r\n"))
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "1\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "b")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)

            try await asyncChannel.writeInbound(ByteBuffer(string: "1\r\nc\r\n"))
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "1\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "c")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)

            try await asyncChannel.writeInbound(ByteBuffer(string: "0\r\n\r\n"))
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "0\r\n\r\n")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)
        }
    }

    @Test("Test Async Echo Handlers")
    func asyncEchoHandlers() async throws {
        try await withApp { app in
            app.on(.post, "echo", body: .stream) { request async throws -> Response in
                var buffers = [ByteBuffer]()

                for try await buffer in request.body {
                    buffers.append(buffer)
                }

                return Response(body: .init(managedAsyncStream: { [buffers] writer in
                    for buffer in buffers {
                        try await writer.writeBuffer(buffer)
                    }
                }))
            }

            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()

            guard
                let localAddress = app.http.server.shared.localAddress,
                let port = localAddress.port
            else {
                Issue.record("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
                return
            }

            let client = HTTPClient()

            let chunks = [
                "1\r\n",
                "a",
                "\r\n",
                "1\r\n",
                "b",
                "\r\n",
                "1\r\n",
                "c",
                "\r\n",
            ]

            let response = try await client.post(url: "http://localhost:\(port)/echo", body: .stream { writer in
                let box = UnsafeMutableTransferBox(writer)
                @Sendable func write(chunks: [String]) -> EventLoopFuture<Void> {
                    var chunks = chunks
                    let chunk = chunks.removeFirst()

                    if chunks.isEmpty {
                        return box.wrappedValue.write(.byteBuffer(ByteBuffer(string: chunk)))
                    } else {
                        return box.wrappedValue.write(.byteBuffer(ByteBuffer(string: chunk))).flatMap { [chunks] in
                            return write(chunks: chunks)
                        }
                    }
                }

                return write(chunks: chunks)
            }).get()

            #expect(response.body?.string == chunks.joined(separator: ""))
            try await client.shutdown()
        }
    }

    @Test("Test Failing Async Handlers")
    func asyncFailingHandlers() async throws {
        try await withApp { app in
            app.on(.post, "fail", body: .stream) { request async throws -> Response in
                return Response(body: .init(managedAsyncStream: { writer in
                    try await writer.writeBuffer(.init(string: "foo"))
                    throw Abort(.internalServerError)
                }))
            }

            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()

            guard
                let localAddress = app.http.server.shared.localAddress,
                let port = localAddress.port
            else {
                Issue.record("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
                return
            }

            let client = HTTPClient()

            do {
                _ = try await client.post(url: "http://localhost:\(port)/fail").get()
                Issue.record("Client has failed to detect broken server response")
            } catch {
                if let error = error as? HTTPParserError {
                    #expect(error == HTTPParserError.invalidEOFState)
                } else {
                    Issue.record("Caught error \"\(error)\"")
                }
            }

            try await client.shutdown()
        }
    }

    @Test("Test EOF Framing")
    func eofFraming() async throws {
        try await withApp { app in
            app.on(.post, "echo", body: .stream) { request -> Response in
                Response(body: .init(stream: { writer in
                    request.body.drain { body in
                        switch body {
                        case .buffer(let buffer):
                            return writer.write(.buffer(buffer))
                        case .error(let error):
                            return writer.write(.error(error))
                        case .end:
                            return writer.write(.end)
                        }
                    }
                }))
            }

            let asyncChannel = NIOAsyncTestingChannel()

            try await asyncChannel.testingEventLoop.flatSubmit {
                asyncChannel.pipeline.addVaporHTTP1Handlers(application: app, responder: app.responder, configuration: app.http.server.configuration)
            }.get()

            try await asyncChannel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\n\r\n"))
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string.contains("HTTP/1.1 200 OK") == true)
        }
    }

    @Test("Test Bad Stream Length")
    func badStreamLength() async throws {
        try await withApp { app in
            app.on(.post, "echo", body: .stream) { request -> Response in
                Response(body: .init(stream: { writer in
                    writer.write(.buffer(.init(string: "a")), promise: nil)
                    writer.write(.end, promise: nil)
                }, count: 2))
            }

            let asyncChannel = NIOAsyncTestingChannel()
            try await asyncChannel.connect(to: .init(unixDomainSocketPath: "/foo"))
            try await asyncChannel.testingEventLoop.flatSubmit {
                asyncChannel.pipeline.addVaporHTTP1Handlers(application: app, responder: app.responder, configuration: app.http.server.configuration)
            }.get()

            #expect(asyncChannel.isActive == true)
            // throws a notEnoughBytes error which is good
            await #expect(throws: Error.self) {
                try await asyncChannel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\n\r\n"))
            }
            #expect(asyncChannel.isActive == false)
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string.contains("HTTP/1.1 200 OK") == true)
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "a")
            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == nil)
        }
    }

    @Test("Test Invalid HTTP")
    func invalidHttp() async throws {
        try await withApp { app in
            let channel = NIOAsyncTestingChannel()
            try await channel.connect(to: .init(unixDomainSocketPath: "/foo"))
            try await channel.testingEventLoop.flatSubmit {
                channel.pipeline.addVaporHTTP1Handlers(
                    application: app,
                    responder: app.responder,
                    configuration: app.http.server.configuration
                )
            }.get()

            #expect(channel.isActive == true)
            let request = ByteBuffer(string: "POST /echo/þ HTTP/1.1\r\n\r\n")
            await #expect(performing: {
                try await channel.writeInbound(request)
            }, throws: { error in
                if let error = error as? HTTPParserError {
                    #expect(error == HTTPParserError.invalidURL)
                    return true
                } else {
                    Issue.record("Caught error \"\(error)\"")
                    return false
                }
            })
            #expect(channel.isActive == false)
            #expect(try await channel.readOutbound(as: ByteBuffer.self)?.string == nil)
        }
    }

    @Test("Returning Response on Different EventLoop Dosent Crash LoopBoundBox")
    func returningResponseOnDifferentEventLoopDosentCrashLoopBoundBox() async throws {
        struct ResponseThing: ResponseEncodable {
            let eventLoop: EventLoop

            func encodeResponse(for request: Vapor.Request) -> NIOCore.EventLoopFuture<Vapor.Response> {
                let response = Response(status: .ok)
                return eventLoop.future(response)
            }
        }

        try await withApp { app in
            let eventLoop = app.eventLoopGroup.next()
            app.get("dont-crash") { req in
                return ResponseThing(eventLoop: eventLoop)
            }

            try await app.testing().test(.get, "dont-crash") { res async in
                #expect(res.status == .ok)
            }

            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()

            guard let localAddress = app.http.server.shared.localAddress,
                  let port = localAddress.port else {
                Issue.record("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
                return
            }

            let res = try await app.client.get("http://localhost:\(port)/dont-crash")
            #expect(res.status == .ok)
        }
    }

    @Test("Returning Response from Middleware on Different EventLoop Dosent Crash LoopBoundBox")
    func returningResponseFromMiddlewareOnDifferentEventLoopDosentCrashLoopBoundBox() async throws {
        struct WrongEventLoopMiddleware: Middleware {
            func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
                next.respond(to: request).hop(to: request.application.eventLoopGroup.next())
            }
        }

        try await withApp { app in
            app.grouped(WrongEventLoopMiddleware()).get("dont-crash") { req in
                return "OK"
            }

            try await app.testing().test(.get, "dont-crash") { res async in
                #expect(res.status == .ok)
            }

            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()

            guard let localAddress = app.http.server.shared.localAddress,
                  let port = localAddress.port else {
                Issue.record("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
                return
            }

            let res = try await app.client.get("http://localhost:\(port)/dont-crash")
            #expect(res.status == .ok)
        }
    }

    @Test("Test Streaming Off EventLoop")
    func streamingOffEventLoop() async throws {
        try await withApp { app in
            let eventLoop = app.eventLoopGroup.next()
            app.on(.post, "stream", body: .stream) { request -> Response in
                Response(body: .init(stream: { writer in
                    request.body.drain { body in
                        switch body {
                        case .buffer(let buffer):
                            return writer.write(.buffer(buffer)).hop(to: eventLoop)
                        case .error(let error):
                            return writer.write(.error(error)).hop(to: eventLoop)
                        case .end:
                            return writer.write(.end).hop(to: eventLoop)
                        }
                    }
                }))
            }

            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()

            guard let localAddress = app.http.server.shared.localAddress,
                  let port = localAddress.port else {
                Issue.record("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
                return
            }

            struct ABody: Content {
                let hello: String

                init() {
                    self.hello = "hello"
                }
            }

            let res = try await app.client.post("http://localhost:\(port)/stream", beforeSend: {
                try $0.content.encode(ABody())
            })
            #expect(res.status == .ok)
        }
    }

    @Test("Test Correct Response Order")
    func correctResponseOrder() async throws {
        try await withApp { app in
            app.get("sleep", ":ms") { req -> String in
                let ms = try req.parameters.require("ms", as: Int64.self)
                try await Task.sleep(for: .milliseconds(ms))
                return "slept \(ms)ms"
            }

            let channel = NIOAsyncTestingChannel()
            _ = try await (channel.eventLoop as! NIOAsyncTestingEventLoop).executeInContext {
                channel.pipeline.addVaporHTTP1Handlers(
                    application: app,
                    responder: app.responder,
                    configuration: app.http.server.configuration
                )
            }

            try await channel.writeInbound(ByteBuffer(string: "GET /sleep/100 HTTP/1.1\r\n\r\nGET /sleep/0 HTTP/1.1\r\n\r\n"))

            // We expect 6 writes to be there - three parts (the head, body and separator for each request). However, if there are less
            // we need to have a timeout to avoid hanging the test
            let deadline = NIODeadline.now() + .seconds(5)
            var responses: [String] = []
            for _ in 0..<6 {
                guard NIODeadline.now() < deadline else {
                    Issue.record("Timed out waiting for responses")
                    return
                }
                let res = try await channel.waitForOutboundWrite(as: ByteBuffer.self).string
                if res.contains("slept") {
                    responses.append(res)
                }
            }

            #expect(responses.count == 2)
            #expect(responses[0] == "slept 100ms")
            #expect(responses[1] == "slept 0ms")
        }
    }

    @Test("Test Correct Response Order Over VaporTCP")
    func correctResponseOrderOverVaporTCP() async throws {
        try await withApp { app in
            app.get("sleep", ":ms") { req -> String in
                let ms = try req.parameters.require("ms", as: Int64.self)
                try await Task.sleep(for: .milliseconds(ms))
                return "slept \(ms)ms"
            }

            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()

            let channel = try await ClientBootstrap(group: app.eventLoopGroup)
                .connect(host: "127.0.0.1", port: app.http.server.configuration.port) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try NIOAsyncChannel(
                            wrappingChannelSynchronously: channel,
                            configuration: NIOAsyncChannel.Configuration(
                                inboundType: ByteBuffer.self,
                                outboundType: ByteBuffer.self
                            )
                        )
                    }
                }

            _ = try await channel.executeThenClose { inbound, outbound in
                try await outbound.write(ByteBuffer(string: "GET /sleep/100 HTTP/1.1\r\n\r\nGET /sleep/0 HTTP/1.1\r\n\r\n"))

                var data = ByteBuffer()
                var sleeps = 0
                for try await chunk in inbound {
                    data.writeImmutableBuffer(chunk)
                    data.writeString("\r\n")

                    if String(decoding: chunk.readableBytesView, as: UTF8.self).components(separatedBy: "\r\n").contains(where: { $0.hasPrefix("slept") }) {
                        sleeps += 1
                    }
                    if sleeps == 2 {
                        break
                    }
                }

                let sleptLines = String(decoding: data.readableBytesView, as: UTF8.self).components(separatedBy: "\r\n").filter { $0.contains("slept") }
                #expect(sleptLines == ["slept 100ms", "slept 0ms"])
                return sleptLines
            }
        }
    }
}
