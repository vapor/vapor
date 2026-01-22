import XCTVapor
import Vapor
import XCTest
import WebSocketKit
import NIOCore
import NIOPosix
import NIOWebSocket

/// Tests for async WebSocket APIs (GitHub Issue #3379)
final class AsyncWebSocketConcurrencyTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        self.app = try await Application.make(test)
    }
    
    override func tearDown() async throws {
        try await self.app.asyncShutdown()
    }
    
    // MARK: - GH#3379 Tests
    
    /// Test async message iteration using for-await-in syntax
    func testGH3379_AsyncMessageIteration() async throws {
        let server = try await Application.make(.testing)
        server.http.server.configuration.port = 0
        
        server.webSocket("echo") { req, ws in
            Task {
                do {
                    for try await message in ws.messages {
                        switch message {
                        case .text(let text):
                            ws.send(text, promise: nil)
                        case .binary(let buffer):
                            ws.send(raw: buffer.readableBytesView, opcode: .binary, promise: nil)
                        case .ping, .pong:
                            break
                        }
                    }
                } catch {
                    // Connection closed
                }
            }
        }
        
        server.environment.arguments = ["serve"]
        try await server.startup()
        
        defer {
            Task {
                try await server.asyncShutdown()
            }
        }
        
        guard let localAddress = server.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get port from \(server.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let promise = elg.next().makePromise(of: String.self)
        
        try await WebSocket.connect(
            to: "ws://localhost:\(port)/echo",
            on: elg.next()
        ) { ws in
            ws.send("Hello from async!", promise: nil)
            ws.onText { ws, text in
                promise.succeed(text)
                ws.close(promise: nil)
            }
        }
        
        let result = try await promise.futureResult.get()
        XCTAssertEqual(result, "Hello from async!")
    }
    
    /// Test async send method
    func testGH3379_AsyncSend() async throws {
        let server = try await Application.make(.testing)
        server.http.server.configuration.port = 0
        
        let sendComplete = expectation(description: "Send completed")
        
        server.webSocket("send-test") { req, ws in
            Task {
                do {
                    try await ws.send("Hello from async send!")
                    sendComplete.fulfill()
                } catch {
                    XCTFail("Async send failed: \(error)")
                }
            }
        }
        
        server.environment.arguments = ["serve"]
        try await server.startup()
        
        defer {
            Task {
                try await server.asyncShutdown()
            }
        }
        
        guard let localAddress = server.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get port from \(server.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let promise = elg.next().makePromise(of: String.self)
        
        try await WebSocket.connect(
            to: "ws://localhost:\(port)/send-test",
            on: elg.next()
        ) { ws in
            ws.onText { ws, text in
                promise.succeed(text)
                ws.close(promise: nil)
            }
        }
        
        let result = try await promise.futureResult.get()
        XCTAssertEqual(result, "Hello from async send!")
        
        await fulfillment(of: [sendComplete], timeout: 5.0)
    }
    
    /// Test async close method
    func testGH3379_AsyncClose() async throws {
        let server = try await Application.make(.testing)
        server.http.server.configuration.port = 0
        
        let closeComplete = expectation(description: "Close completed")
        
        server.webSocket("close-test") { req, ws in
            ws.onText { ws, text in
                if text == "close" {
                    Task<Void, Never> {
                        do {
                            try await ws.close(code: .normalClosure)
                            closeComplete.fulfill()
                        } catch {
                            XCTFail("Async close failed: \(error)")
                        }
                    }
                }
            }
        }
        
        server.environment.arguments = ["serve"]
        try await server.startup()
        
        defer {
            Task {
                try await server.asyncShutdown()
            }
        }
        
        guard let localAddress = server.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get port from \(server.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let closedPromise = elg.next().makePromise(of: Void.self)
        
        try await WebSocket.connect(
            to: "ws://localhost:\(port)/close-test",
            on: elg.next()
        ) { ws in
            ws.send("close", promise: nil)
            ws.onClose.whenComplete { _ in
                closedPromise.succeed(())
            }
        }
        
        try await closedPromise.futureResult.get()
        await fulfillment(of: [closeComplete], timeout: 5.0)
    }
    
    /// Test binary data send via async method
    func testGH3379_AsyncBinarySend() async throws {
        let server = try await Application.make(.testing)
        server.http.server.configuration.port = 0
        
        let testData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        
        server.webSocket("binary-test") { req, ws in
            Task<Void, Never> {
                do {
                    try await ws.send(raw: testData, opcode: .binary)
                } catch {
                    // Handle error
                }
            }
        }
        
        server.environment.arguments = ["serve"]
        try await server.startup()
        
        defer {
            Task {
                try await server.asyncShutdown()
            }
        }
        
        guard let localAddress = server.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get port from \(server.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let promise = elg.next().makePromise(of: [UInt8].self)
        
        try await WebSocket.connect(
            to: "ws://localhost:\(port)/binary-test",
            on: elg.next()
        ) { ws in
            ws.onBinary { ws, buffer in
                var mutableBuffer = buffer
                let bytes = mutableBuffer.readBytes(length: buffer.readableBytes) ?? []
                promise.succeed(bytes)
                ws.close(promise: nil)
            }
        }
        
        let result = try await promise.futureResult.get()
        XCTAssertEqual(result, testData)
    }
    
    /// Test Message enum exhaustive pattern matching
    func testGH3379_MessageEnum() async throws {
        let textMessage: WebSocket.Message = .text("Hello")
        let binaryMessage: WebSocket.Message = .binary(ByteBufferAllocator().buffer(capacity: 0))
        let pingMessage: WebSocket.Message = .ping(ByteBufferAllocator().buffer(capacity: 0))
        let pongMessage: WebSocket.Message = .pong(ByteBufferAllocator().buffer(capacity: 0))
        
        switch textMessage {
        case .text(let text):
            XCTAssertEqual(text, "Hello")
        case .binary, .ping, .pong:
            XCTFail("Expected text message")
        }
        
        switch binaryMessage {
        case .binary:
            break // Expected
        case .text, .ping, .pong:
            XCTFail("Expected binary message")
        }
        
        switch pingMessage {
        case .ping:
            break // Expected
        case .text, .binary, .pong:
            XCTFail("Expected ping message")
        }
        
        switch pongMessage {
        case .pong:
            break // Expected
        case .text, .binary, .ping:
            XCTFail("Expected pong message")
        }
    }
}
