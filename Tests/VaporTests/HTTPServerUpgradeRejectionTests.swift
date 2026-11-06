@testable import Vapor
import NIOCore
import NIOHTTP1
import NIOEmbedded
import NIOPosix
import NIOConcurrencyHelpers
import XCTest

// These tests deliberately exercise the supported future-based channel API.
@available(*, deprecated, message: "Test future-based HTTP/1 channel lifecycle")
final class HTTPServerUpgradeRejectionTests: XCTestCase {
    private enum Failure: Error { case write, missingMarker }

    /// Holds output-close completion to model pending socket writes. A successful
    /// Response promise alone must never cause a full close before this gate.
    private final class TransportGate: ChannelOutboundHandler {
        typealias OutboundIn = Response
        var response: Response?
        var written: EventLoopPromise<Void>?
        var outputClose: EventLoopPromise<Void>?
        var closeModes: [CloseMode] = []

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            self.response = self.unwrapOutboundIn(data)
            self.written = promise
        }

        func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
            self.closeModes.append(mode)
            if mode == .output {
                self.outputClose = promise
            } else {
                context.close(mode: mode, promise: promise)
            }
        }
    }

    private final class HTTPPartSink: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        var parts = 0
        func channelRead(context: ChannelHandlerContext, data: NIOAny) { self.parts += 1 }
    }

    private func withHandler(_ body: (EmbeddedChannel, HTTPPartSink, TransportGate, Request) throws -> Void) throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let channel = EmbeddedChannel()
        defer { _ = try? channel.finish() }
        try channel.connect(to: SocketAddress(unixDomainSocketPath: "/embedded-upgrade-rejection")).wait()
        let transport = TransportGate()
        let decoder = ByteToMessageHandler(HTTPRequestDecoder())
        let sink = HTTPPartSink()
        let handler = HTTPServerUpgradeHandler(httpRequestDecoder: decoder, httpHandlers: [])
        try channel.pipeline.syncOperations.addHandlers([transport, decoder, sink, handler])
        let request = Request(application: app, method: .GET, url: "/retired", on: channel.eventLoop)
        request.headers.replaceOrAdd(name: .connection, value: "upgrade")
        request.headers.replaceOrAdd(name: .upgrade, value: "fixture-protocol")
        let context = try channel.pipeline.syncOperations.context(handler: handler)
        handler.channelRead(context: context, data: NIOAny(request))
        _ = try channel.readInbound(as: Request.self)
        try body(channel, sink, transport, request)
    }

    func testRejectedUpgradeDrainsBeforeFullCloseAndDiscardsBufferedInput() throws {
        try self.withHandler { channel, sink, transport, _ in
            // Already buffered input must be freed without replay; later input
            // must not be decoded while the refusal is completing.
            try channel.writeInbound(ByteBuffer(string: "POST /must-not-run HTTP/1.1\r\n\r\n"))
            let completions = NIOLockedValueBox(0)
            let caller = channel.eventLoop.makePromise(of: Void.self)
            caller.futureResult.whenComplete { _ in completions.withLockedValue { $0 += 1 } }
            let response = Response(status: .gone, headers: ["connection": "keep-alive"], body: .init(string: "retired"))
            channel.writeAndFlush(NIOAny(response), promise: caller)
            XCTAssertEqual(transport.response?.headers[.connection], ["close"])
            XCTAssertNotNil(transport.written)
            XCTAssertTrue(transport.closeModes.isEmpty)
            try channel.writeInbound(ByteBuffer(string: "POST /also-must-not-run HTTP/1.1\r\n\r\n"))
            XCTAssertEqual(sink.parts, 0)
            XCTAssertNil(try channel.readInbound(as: ByteBuffer.self))

            transport.written?.succeed(())
            channel.embeddedEventLoop.run()
            try caller.futureResult.wait()
            XCTAssertEqual(completions.withLockedValue { $0 }, 1)
            XCTAssertEqual(transport.closeModes, [.output])
            XCTAssertTrue(channel.isActive)
            transport.outputClose?.succeed(())
            channel.embeddedEventLoop.run()
            XCTAssertEqual(transport.closeModes, [.output, .all])
            XCTAssertFalse(channel.isActive)
            XCTAssertEqual(sink.parts, 0)
            XCTAssertNil(try channel.readInbound(as: ByteBuffer.self))
        }
    }

    func testRejectedUpgradeClosesWithNilCallerPromise() throws {
        try self.withHandler { channel, _, transport, _ in
            channel.writeAndFlush(NIOAny(Response(status: .gone)), promise: nil)
            let written = try XCTUnwrap(transport.written)
            written.succeed(())
            channel.embeddedEventLoop.run()
            XCTAssertEqual(transport.closeModes, [.output])
            try XCTUnwrap(transport.outputClose).succeed(())
            channel.embeddedEventLoop.run()
            XCTAssertEqual(transport.closeModes, [.output, .all])
            XCTAssertFalse(channel.isActive)
        }
    }

    func testRejectedUpgradeWriteFailureIsPreservedAndClosesOnce() throws {
        try self.withHandler { channel, _, transport, _ in
            let completions = NIOLockedValueBox(0)
            let caller = channel.eventLoop.makePromise(of: Void.self)
            caller.futureResult.whenComplete { _ in completions.withLockedValue { $0 += 1 } }
            channel.writeAndFlush(NIOAny(Response(status: .gone)), promise: caller)
            try XCTUnwrap(transport.written).fail(Failure.write)
            channel.embeddedEventLoop.run()
            XCTAssertThrowsError(try caller.futureResult.wait()) { error in
                guard case Failure.write = error else { return XCTFail("Original write failure was not preserved") }
            }
            XCTAssertEqual(completions.withLockedValue { $0 }, 1)
            XCTAssertEqual(transport.closeModes, [.all])
            XCTAssertFalse(channel.isActive)
        }
    }

    func testUnusable101AlsoRetiresAttemptedUpgrade() throws {
        try self.withHandler { channel, _, transport, _ in
            // Generic pending-upgrade branch: a status alone is not an upgrader.
            channel.writeAndFlush(NIOAny(Response(status: .switchingProtocols)), promise: nil)
            try XCTUnwrap(transport.written).succeed(())
            channel.embeddedEventLoop.run()
            XCTAssertEqual(transport.response?.headers[.connection], ["close"])
            XCTAssertEqual(transport.closeModes, [.output])
            try XCTUnwrap(transport.outputClose).succeed(())
            channel.embeddedEventLoop.run()
            XCTAssertFalse(channel.isActive)
        }
    }

    private struct WireResult: Sendable {
        var bytes: ByteBuffer
        var localClose: Bool
        var failed: Bool
        var elapsed: UInt64
    }

    /// Actual transport EOF is observed before test cleanup. This cooperative
    /// 3 s timer is a failure bound, never evidence of successful peer closure.
    // Mutable state is confined to the one bootstrap event loop. Only the
    // immutable promises are read by the calling test thread.
    private final class WireReceipt: ChannelInboundHandler, @unchecked Sendable {
        typealias InboundIn = ByteBuffer
        let result: EventLoopPromise<WireResult>
        let firstChunk: EventLoopPromise<Void>
        private var bytes = ByteBuffer()
        private var localClose = false
        private var failed = false
        private var markerSeen = false
        private var timer: Scheduled<Void>?
        private var started = NIODeadline.now().uptimeNanoseconds

        init(on loop: EventLoop) {
            self.result = loop.makePromise(of: WireResult.self)
            self.firstChunk = loop.makePromise(of: Void.self)
        }

        func handlerAdded(context: ChannelHandlerContext) {
            self.started = NIODeadline.now().uptimeNanoseconds
            let box = NIOLoopBound((self, context), eventLoop: context.eventLoop)
            self.timer = context.eventLoop.scheduleTask(in: .seconds(3)) {
                let (handler, context) = box.value
                handler.localClose = true
                handler.failed = true
                context.close(promise: nil)
            }
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var chunk = self.unwrapInboundIn(data)
            guard self.bytes.readableBytes + chunk.readableBytes <= 65_536 else {
                self.failed = true
                self.localClose = true
                context.close(promise: nil)
                return
            }
            self.bytes.writeBuffer(&chunk)
            if !self.markerSeen && String(decoding: self.bytes.readableBytesView, as: UTF8.self).contains("first") {
                self.markerSeen = true
                self.firstChunk.succeed(())
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            self.failed = true
            self.localClose = true
            context.close(promise: nil)
        }

        func channelInactive(context: ChannelHandlerContext) {
            self.timer?.cancel()
            if !self.markerSeen { self.firstChunk.fail(Failure.missingMarker) }
            self.result.succeed(.init(bytes: self.bytes, localClose: self.localClose, failed: self.failed,
                elapsed: NIODeadline.now().uptimeNanoseconds - self.started))
            context.fireChannelInactive()
        }
    }

    private func exchange(_ app: Application, _ request: String, firstChunk: (() throws -> Void)? = nil) throws -> WireResult {
        let address = try XCTUnwrap(app.http.server.shared.localAddress)
        let port = try XCTUnwrap(address.port)
        let loop = app.eventLoopGroup.next()
        let receipt = WireReceipt(on: loop)
        let channel = try ClientBootstrap(group: loop)
            .connectTimeout(.seconds(2))
            .channelInitializer { channel in channel.pipeline.addHandler(receipt) }
            .connect(to: SocketAddress(ipAddress: "127.0.0.1", port: port)).wait()
        defer {
            _ = try? channel.close().wait()
            try? channel.closeFuture.wait()
        }
        try channel.writeAndFlush(NIOAny(ByteBuffer(string: request))).wait()
        if let firstChunk {
            try receipt.firstChunk.futureResult.wait()
            XCTAssertTrue(channel.isActive)
            try firstChunk()
        }
        let result = try receipt.result.futureResult.wait()
        try channel.closeFuture.wait()
        XCTAssertFalse(result.localClose, "Only peer close before cleanup qualifies")
        XCTAssertFalse(result.failed)
        XCTAssertLessThan(result.elapsed, 3_000_000_000)
        XCTAssertFalse(channel.isActive)
        // The same closed channel must refuse immediately; no reconnect or
        // 3 s response wait is used to manufacture a successful subsequent POST.
        XCTAssertThrowsError(try channel.writeAndFlush(NIOAny(ByteBuffer(string: "POST /fresh HTTP/1.1\r\ncontent-length: 0\r\n\r\n"))).wait())
        return result
    }

    private func start(_ app: Application) throws {
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        app.environment.arguments = ["serve"]
        try app.start()
    }

    private var refusedRequest: String {
        "GET /retired HTTP/1.1\r\nhost: localhost\r\nconnection: upgrade\r\nupgrade: fixture-protocol\r\n\r\n"
    }

    func testComplete410ThenPeerCloseAndFresh200() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let posts = NIOLockedValueBox(0)
        app.get("retired") { _ in Response(status: .gone, body: .init(string: "retired")) }
        app.post("fresh") { _ -> String in posts.withLockedValue { $0 += 1 }; return "fresh" }
        try self.start(app)
        let pipelined = "POST /fresh HTTP/1.1\r\nhost: localhost\r\ncontent-length: 0\r\n\r\n"
        let rejected = try self.exchange(app, self.refusedRequest + pipelined)
        let text = String(decoding: rejected.bytes.readableBytesView, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 410 Gone\r\n"))
        XCTAssertTrue(text.lowercased().contains("connection: close\r\n"))
        XCTAssertEqual(text.components(separatedBy: "\r\n\r\n").last, "retired")
        XCTAssertEqual(posts.withLockedValue { $0 }, 0)
        let fresh = try self.exchange(app, "POST /fresh HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\ncontent-length: 0\r\n\r\n")
        XCTAssertTrue(String(decoding: fresh.bytes.readableBytesView, as: UTF8.self).hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertEqual(posts.withLockedValue { $0 }, 1)
    }

    func testOrdinary410KeepsHTTPConnectionReusable() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.get("retired") { _ in Response(status: .gone, body: .init(string: "retired")) }
        app.post("fresh") { _ in "fresh" }
        try self.start(app)
        let result = try self.exchange(app,
            "GET /retired HTTP/1.1\r\nhost: localhost\r\n\r\n" +
            "POST /fresh HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\ncontent-length: 0\r\n\r\n")
        let text = String(decoding: result.bytes.readableBytesView, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 410 Gone\r\n"))
        XCTAssertTrue(text.contains("retiredHTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n\r\nfresh"))
    }

    func testChunked410FinishesBeforeClose() throws {
        try self.checkStreamedRefusal(useAsync: false)
    }

    func testAsyncChunked410FinishesBeforeClose() throws {
        try self.checkStreamedRefusal(useAsync: true)
    }

    func testFailedStreamClosesWithoutClaimingCompleteRefusal() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.get("retired") { _ in
            Response(status: .gone, body: .init(managedAsyncStream: { writer in
                try await writer.writeBuffer(ByteBuffer(string: "first"))
                throw Failure.write
            }))
        }
        try self.start(app)
        let result = try self.exchange(app, self.refusedRequest)
        let text = String(decoding: result.bytes.readableBytesView, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 410 Gone\r\n"))
        XCTAssertTrue(text.contains("5\r\nfirst\r\n"))
        XCTAssertFalse(text.hasSuffix("0\r\n\r\n"), "A failed stream is not a complete refusal")
    }

    private func checkStreamedRefusal(useAsync: Bool) throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let release = app.eventLoopGroup.next().makePromise(of: Void.self)
        let released = NIOLockedValueBox(false)
        @Sendable func releaseOnce() {
            let first = released.withLockedValue { value in
                guard !value else { return false }
                value = true
                return true
            }
            if first { release.succeed(()) }
        }
        // Always release a started writer on an assertion/transport failure.
        defer { releaseOnce() }
        app.get("retired") { request -> Response in
            if useAsync {
                return Response(status: .gone, body: .init(managedAsyncStream: { writer in
                    try await writer.writeBuffer(ByteBuffer(string: "first"))
                    try await release.futureResult.get()
                    try await writer.writeBuffer(ByteBuffer(string: "second"))
                }))
            }
            return Response(status: .gone, body: .init(stream: { writer in
                writer.write(.buffer(ByteBuffer(string: "first")), promise: nil)
                release.futureResult.hop(to: request.eventLoop).whenSuccess { _ in
                    writer.write(.buffer(ByteBuffer(string: "second")), promise: nil)
                    writer.write(.end, promise: nil)
                }
            }))
        }
        try self.start(app)
        let result = try self.exchange(app, self.refusedRequest, firstChunk: { releaseOnce() })
        let text = String(decoding: result.bytes.readableBytesView, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 410 Gone\r\n"))
        XCTAssertTrue(text.lowercased().contains("transfer-encoding: chunked\r\n"))
        let separator = try XCTUnwrap(text.range(of: "\r\n\r\n"))
        XCTAssertEqual(String(text[separator.upperBound...]), "5\r\nfirst\r\n6\r\nsecond\r\n0\r\n\r\n")
    }
}
