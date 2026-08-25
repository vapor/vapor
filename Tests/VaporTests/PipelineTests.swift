@testable import Vapor
import enum NIOHTTP1.HTTPParserError
import AsyncHTTPClient
import NIOEmbedded
import NIOCore
import NIOConcurrencyHelpers
import class NIOPosix.ClientBootstrap
import Testing
import VaporTesting

/// What's left here is request-body streaming: these tests drive `app.on(..., body: .stream)` and
/// `request.body.drain`, which the new server doesn't implement yet. They're kept commented as a
/// reference for that work — the harness they use (`addVaporHTTP1Handlers`, `NIOAsyncTestingChannel`)
/// is gone, so they need rewriting rather than uncommenting.
///
/// The rest of the file's tests were removed: response ordering and invalid HTTP moved to
/// `StreamingBodyTests` as socket-level tests, bad stream length is covered by
/// `testBadStreamLengthDoesNotBreakServer`, and the `EventLoop`-hopping ones tested hazards that
/// structured concurrency removed.
@Suite("Pipeline Tests", .disabled("Request body streaming is not implemented on the new server"))
struct PipelineTests {
//    @Test("Test Echo Handlers")
//    func echoHandlers() async throws {
//        try await withApp { app in
//            app.on(.post, "echo", body: .stream) { request -> Response in
//                Response(body: .init(stream: { writer in
//                    request.body.drain { body in
//                        switch body {
//                        case .buffer(let buffer):
//                            return writer.write(.buffer(buffer))
//                        case .error(let error):
//                            return writer.write(.error(error))
//                        case .end:
//                            return writer.write(.end)
//                        }
//                    }
//                }))
//            }
//
//            let asyncChannel = NIOAsyncTestingChannel()
//
//            let responder: any Responder
//            switch app.responder {
//            case .provided(let provided):
//                responder = provided
//            case .default:
//                responder = DefaultResponder(routes: app.routes)
//            }
//
//            try await asyncChannel.testingEventLoop.flatSubmit {
//                asyncChannel.pipeline.addVaporHTTP1Handlers(application: app, responder: responder, configuration: app.http.server.configuration)
//            }.get()
//
//            try await asyncChannel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\ntransfer-encoding: chunked\r\n\r\n1\r\na\r\n"))
//            let chunk = try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string
//            #expect(chunk?.contains("HTTP/1.1 200 OK") == true)
//            #expect(chunk?.contains("connection: keep-alive") == true)
//            #expect(chunk?.contains("transfer-encoding: chunked") == true)
//
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "1\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "a")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)
//
//            try await asyncChannel.writeInbound(ByteBuffer(string: "1\r\nb\r\n"))
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "1\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "b")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)
//
//            try await asyncChannel.writeInbound(ByteBuffer(string: "1\r\nc\r\n"))
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "1\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "c")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)
//
//            try await asyncChannel.writeInbound(ByteBuffer(string: "0\r\n\r\n"))
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string == "0\r\n\r\n")
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self) == nil)
//        }
//    }
//
//    @Test("Test Async Echo Handlers")
//    func asyncEchoHandlers() async throws {
//        try await withApp { app in
//            app.on(.post, "echo", body: .stream) { request async throws -> Response in
//                var buffers = [ByteBuffer]()
//
//                for try await buffer in request.body {
//                    buffers.append(buffer)
//                }
//
//                return Response(body: .init(managedAsyncStream: { [buffers] writer in
//                    for buffer in buffers {
//                        try await writer.writeBuffer(buffer)
//                    }
//                }))
//            }
//
//            app.environment.arguments = ["serve"]
//            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
//            try await app.startup()
//
//            guard
//                let localAddress = app.http.server.shared.localAddress,
//                let port = localAddress.port
//            else {
//                Issue.record("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
//                return
//            }
//
//            let client = HTTPClient()
//
//            let chunks = [
//                "1\r\n",
//                "a",
//                "\r\n",
//                "1\r\n",
//                "b",
//                "\r\n",
//                "1\r\n",
//                "c",
//                "\r\n",
//            ]
//
//            let response = try await client.post(url: "http://localhost:\(port)/echo", body: .stream { writer in
//                let box = UnsafeMutableTransferBox(writer)
//                @Sendable func write(chunks: [String]) -> EventLoopFuture<Void> {
//                    var chunks = chunks
//                    let chunk = chunks.removeFirst()
//
//                    if chunks.isEmpty {
//                        return box.wrappedValue.write(.byteBuffer(ByteBuffer(string: chunk)))
//                    } else {
//                        return box.wrappedValue.write(.byteBuffer(ByteBuffer(string: chunk))).flatMap { [chunks] in
//                            return write(chunks: chunks)
//                        }
//                    }
//                }
//
//                return write(chunks: chunks)
//            }).get()
//
//            #expect(response.body?.string == chunks.joined(separator: ""))
//            try await client.shutdown()
//        }
//    }
//
//    @Test("Test Failing Async Handlers")
//    func asyncFailingHandlers() async throws {
//        try await withApp { app in
//            app.on(.post, "fail", body: .stream) { request async throws -> Response in
//                return Response(body: .init(managedAsyncStream: { writer in
//                    try await writer.writeBuffer(.init(string: "foo"))
//                    throw Abort(.internalServerError)
//                }))
//            }
//
//            app.environment.arguments = ["serve"]
//            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
//            try await app.startup()
//
//            guard
//                let localAddress = app.http.server.shared.localAddress,
//                let port = localAddress.port
//            else {
//                Issue.record("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
//                return
//            }
//
//            let client = HTTPClient()
//
//            do {
//                _ = try await client.post(url: "http://localhost:\(port)/fail").get()
//                Issue.record("Client has failed to detect broken server response")
//            } catch {
//                if let error = error as? HTTPParserError {
//                    #expect(error == HTTPParserError.invalidEOFState)
//                } else {
//                    Issue.record("Caught error \"\(error)\"")
//                }
//            }
//
//            try await client.shutdown()
//        }
//    }
//
//    @Test("Test EOF Framing")
//    func eofFraming() async throws {
//        try await withApp { app in
//            app.on(.post, "echo", body: .stream) { request -> Response in
//                Response(body: .init(stream: { writer in
//                    request.body.drain { body in
//                        switch body {
//                        case .buffer(let buffer):
//                            return writer.write(.buffer(buffer))
//                        case .error(let error):
//                            return writer.write(.error(error))
//                        case .end:
//                            return writer.write(.end)
//                        }
//                    }
//                }))
//            }
//
//            let asyncChannel = NIOAsyncTestingChannel()
//
//            let responder: any Responder
//            switch app.responder {
//            case .provided(let provided):
//                responder = provided
//            case .default:
//                responder = DefaultResponder(routes: app.routes)
//            }
//
//            try await asyncChannel.testingEventLoop.flatSubmit {
//                asyncChannel.pipeline.addVaporHTTP1Handlers(application: app, responder: responder, configuration: app.http.server.configuration)
//            }.get()
//
//            try await asyncChannel.writeInbound(ByteBuffer(string: "POST /echo HTTP/1.1\r\n\r\n"))
//            #expect(try await asyncChannel.readOutbound(as: ByteBuffer.self)?.string.contains("HTTP/1.1 200 OK") == true)
//        }
//    }
}
