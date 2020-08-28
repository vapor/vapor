@testable import Vapor
import XCTest

final class PipelineTests: XCTestCase {
    func testEchoHandlers() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

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
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

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
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

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
        try channel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\n\r\n"))
        XCTAssertEqual(channel.isActive, false)
        try XCTAssertContains(channel.readOutbound(as: ByteBuffer.self)?.string, "HTTP/1.1 200 OK")
        try XCTAssertEqual(channel.readOutbound(as: ByteBuffer.self)?.string, "a")
        try XCTAssertNil(channel.readOutbound(as: ByteBuffer.self)?.string)
    }

    override class func setUp() {
        XCTAssert(isLoggingConfigured)
    }
}
