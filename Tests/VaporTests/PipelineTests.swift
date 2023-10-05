@testable import Vapor
import enum NIOHTTP1.HTTPParserError
import XCTest
import NIOEmbedded
import NIOCore

final class PipelineTests: XCTestCase {
    var app: Application!
    var eventLoopGroup: EventLoopGroup!
    
    override func setUp() async throws {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 8)
        app = Application(.testing, .shared(eventLoopGroup))
    }
    
    override func tearDown() async throws {
        app.shutdown()
        try await eventLoopGroup.shutdownGracefully()
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
        
        try app.test(.GET, "dont-crash") { res in
            XCTAssertEqual(res.status, .ok)
        }

        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try app.start()
        
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
        
        try app.test(.GET, "dont-crash") { res in
            XCTAssertEqual(res.status, .ok)
        }

        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try app.start()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let res = try await app.client.get("http://localhost:\(port)/dont-crash")
        XCTAssertEqual(res.status, .ok)
    }

    override class func setUp() {
        XCTAssert(isLoggingConfigured)
    }
}
