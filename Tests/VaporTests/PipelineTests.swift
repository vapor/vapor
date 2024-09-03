@testable import Vapor
import enum NIOHTTP1.HTTPParserError
import XCTest
import AsyncHTTPClient
import NIOEmbedded
import NIOCore
import NIOConcurrencyHelpers

final class PipelineTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    
    func testEchoHandlers() throws {
        app.on(.POST, "echo", body: .stream) { request -> Response in
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

        let channel = EmbeddedChannel()
        try channel.pipeline.addVaporHTTP1Handlers(
            application: app,
            responder: app.responder,
            configuration: app.http.server.configuration
        ).wait()

        try channel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\ntransfer-encoding: chunked\r\n\r\n1\r\na\r\n"))
        let chunk = try channel.readOutbound(as: ByteBuffer.self)?.string
        XCTAssertContains(chunk, "HTTP/1.1 200 OK")
        XCTAssertContains(chunk, "connection: keep-alive")
        XCTAssertContains(chunk, "transfer-encoding: chunked")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "1\r\n")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "a")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "\r\n")
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)

        try channel.writeInbound(ByteBuffer(string: "1\r\nb\r\n"))
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "1\r\n")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "b")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "\r\n")
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)

        try channel.writeInbound(ByteBuffer(string: "1\r\nc\r\n"))
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "1\r\n")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "c")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "\r\n")
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)

        try channel.writeInbound(ByteBuffer(string: "0\r\n\r\n"))
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "0\r\n\r\n")
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)
    }

    func testAsyncEchoHandlers() async throws {
        app.on(.POST, "echo", body: .stream) { request async throws -> Response in
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
            XCTFail("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
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
        
        XCTAssertEqual(response.body?.string, chunks.joined(separator: ""))
        try await client.shutdown()
    }

    func testEOFFraming() throws {
        app.on(.POST, "echo", body: .stream) { request -> Response in
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

        let channel = EmbeddedChannel()
        try channel.pipeline.addVaporHTTP1Handlers(
            application: app,
            responder: app.responder,
            configuration: app.http.server.configuration
        ).wait()

        try channel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\n\r\n"))
        try XCTAssertContains(channel.readOutbound(as: ByteBuffer.self)?.string, "HTTP/1.1 200 OK")
    }

    func testBadStreamLength() throws {
        app.on(.POST, "echo", body: .stream) { request -> Response in
            Response(body: .init(stream: { writer in
                writer.write(.buffer(.init(string: "a")), promise: nil)
                writer.write(.end, promise: nil)
            }, count: 2))
        }

        let channel = EmbeddedChannel()
        try channel.connect(to: .init(unixDomainSocketPath: "/foo")).wait()
        try channel.pipeline.addVaporHTTP1Handlers(
            application: app,
            responder: app.responder,
            configuration: app.http.server.configuration
        ).wait()

        XCTAssertEqual(channel.isActive, true)
        // throws a notEnoughBytes error which is good
        XCTAssertThrowsError(try channel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\n\r\n")))
        XCTAssertEqual(channel.isActive, false)
        try XCTAssertContains(channel.readOutbound(as: ByteBuffer.self)?.string, "HTTP/1.1 200 OK")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "a")
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)
    }
    
    func testInvalidHttp() throws {
        let channel = EmbeddedChannel()
        try channel.connect(to: .init(unixDomainSocketPath: "/foo")).wait()
        try channel.pipeline.addVaporHTTP1Handlers(
            application: app,
            responder: app.responder,
            configuration: app.http.server.configuration
        ).wait()

        XCTAssertEqual(channel.isActive, true)
        let request = ByteBuffer(string: "POST /echo/þ HTTP/1.1\r\n\r\n")
        XCTAssertThrowsError(try channel.writeInbound(request)) { error in
            if let error = error as? HTTPParserError {
                XCTAssertEqual(error, HTTPParserError.invalidURL)
            } else {
                XCTFail("Caught error \"\(error)\"")
            }
        }
        XCTAssertEqual(channel.isActive, false)
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)
    }
    
    func testReturningResponseOnDifferentEventLoopDosentCrashLoopBoundBox() async throws {
        struct ResponseThing: ResponseEncodable {
            let eventLoop: EventLoop
            
            func encodeResponse(for request: Vapor.Request) -> NIOCore.EventLoopFuture<Vapor.Response> {
                let response = Response(status: .ok)
                return eventLoop.future(response)
            }
        }
        
        let eventLoop = app!.eventLoopGroup.next()
        app.get("dont-crash") { req in
            return ResponseThing(eventLoop: eventLoop)
        }
        
        try await app.test(.GET, "dont-crash") { res async in
            XCTAssertEqual(res.status, .ok)
        }

        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try await app.startup()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let res = try await app.client.get("http://localhost:\(port)/dont-crash")
        XCTAssertEqual(res.status, .ok)
    }
    
    func testReturningResponseFromMiddlewareOnDifferentEventLoopDosentCrashLoopBoundBox() async throws {
        struct WrongEventLoopMiddleware: Middleware {
            func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
                next.respond(to: request).hop(to: request.application.eventLoopGroup.next())
            }
        }
        
        app.grouped(WrongEventLoopMiddleware()).get("dont-crash") { req in
            return "OK"
        }
        
        try await app.test(.GET, "dont-crash") { res async in
            XCTAssertEqual(res.status, .ok)
        }

        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try await app.startup()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let res = try await app.client.get("http://localhost:\(port)/dont-crash")
        XCTAssertEqual(res.status, .ok)
    }
    
    func testStreamingOffEventLoop() async throws {
        let eventLoop = app.eventLoopGroup.next()
        app.on(.POST, "stream", body: .stream) { request -> Response in
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
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
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
        XCTAssertEqual(res.status, .ok)
    }

    func testCorrectResponseOrder() async throws {
        app.get("sleep", ":ms") { req -> String in
            let ms = try req.parameters.require("ms", as: Int64.self)
            try await Task.sleep(for: .milliseconds(ms))
            return "slept \(ms)ms"
        }

        let channel = NIOAsyncTestingChannel()
        let app = self.app!
        _ = try await (channel.eventLoop as! NIOAsyncTestingEventLoop).executeInContext {
            channel.pipeline.addVaporHTTP1Handlers(
                application: app,
                responder: app.responder,
                configuration: app.http.server.configuration
            )
        }

        try await channel.writeInbound(ByteBuffer(string: "GET /sleep/100 HTTP/1.1\r\n\r\nGET /sleep/0 HTTP/1.1\r\n\r\n"))

        // We expect 6 responses to be there, however if there are less
        // we need to have a timeout to avoid hanging the test
        let deadline = NIODeadline.now() + .milliseconds(200)
        var responses: [String] = []
        for _ in 0..<6 {
            guard NIODeadline.now() < deadline else {
                XCTFail("Timed out waiting for responses")
                return
            }
            let res = try await channel.waitForOutboundWrite(as: ByteBuffer.self).string
            if res.contains("slept") {
                responses.append(res)
            }
        }

        XCTAssertEqual(responses.count, 2)
        XCTAssertEqual(responses[0], "slept 100ms")
        XCTAssertEqual(responses[1], "slept 0ms")
    }

    override class func setUp() {
        XCTAssert(isLoggingConfigured)
    }
}
