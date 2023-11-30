@testable import Vapor
import enum NIOHTTP1.HTTPParserError
import XCTest
import NIOEmbedded
import NIOCore

final class PipelineTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    
    func testEchoHandlers() async throws {
        app.on(.POST, "echo", body: .stream) { request -> Response in
            return Response(body: .init(stream: { writer in
                request.body.drain { body in
                    switch body {
                    case .buffer(let buffer):
                        print("Received \(String(buffer: buffer))")
                        return writer.write(.buffer(buffer))
                    case .error(let error):
                        return writer.write(.error(error))
                    case .end:
                        return writer.write(.end)
                    }
                }
            }))
        }

        let channel = NIOAsyncTestingChannel()
        try await channel.pipeline.addVaporHTTP1Handlers(
            application: app,
            responder: app.responder,
            configuration: app.http.server.configuration
        ).get()

        try await channel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\ntransfer-encoding: chunked\r\n\r\n1\r\na\r\n"))
        // Hack to work around a/a and ELF bridge in tests
        sleep(1)
        let chunk = try await channel.readOutbound(as: ByteBuffer.self)?.string
        XCTAssertContains(chunk, "HTTP/1.1 200 OK")
        XCTAssertContains(chunk, "connection: keep-alive")
        XCTAssertContains(chunk, "transfer-encoding: chunked")

        let chunk1 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk2 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk3 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk4 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        
        XCTAssertEqual(chunk1, "1\r\n")
        XCTAssertEqual(chunk2, "a")
        XCTAssertEqual(chunk3, "\r\n")
        XCTAssertNil(chunk4)

        try await channel.writeInbound(ByteBuffer(string: "1\r\nb\r\n"))
        let chunk5 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk6 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk7 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk8 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        XCTAssertEqual(chunk5, "1\r\n")
        XCTAssertEqual(chunk6, "b")
        XCTAssertEqual(chunk7, "\r\n")
        XCTAssertNil(chunk8)

        try await channel.writeInbound(ByteBuffer(string: "1\r\nc\r\n"))
        let chunk9 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk10 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk11 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk12 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        XCTAssertEqual(chunk9, "1\r\n")
        XCTAssertEqual(chunk10, "c")
        XCTAssertEqual(chunk11, "\r\n")
        XCTAssertNil(chunk12)

        try await channel.writeInbound(ByteBuffer(string: "0\r\n\r\n"))
        let chunk13 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        let chunk14 = try await channel.readOutbound(as: ByteBuffer.self)?.string
        XCTAssertEqual(chunk13, "0\r\n\r\n")
        XCTAssertNil(chunk14)
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
        sleep(1)
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
    
    @available(*, deprecated, message: "Checking ELF stuff")
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

    override class func setUp() {
        XCTAssert(isLoggingConfigured)
    }
}
