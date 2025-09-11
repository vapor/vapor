#if Websockets
import VaporTesting
import Vapor
import Testing
import WebSocketKit
import NIOCore
import NIOPosix

@Suite("Websocket Tests", .disabled())
struct WebSocketTests {
    @Test("Test WebSocket Client")
    func testWebSocketClient() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            app.webSocket("echo") { req, ws in
                ws.onText { ws.send($1) }
            }
            try await app.startup()

            let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port)
            let promise = MultiThreadedEventLoopGroup.singleton.next().makePromise(of: String.self)
            try await WebSocket.connect(
                to: "ws://localhost:\(port)/echo",
                on: MultiThreadedEventLoopGroup.singleton.any()
            ) { ws in
                ws.send("Hello, world!")
                ws.onText { ws, text in
                    promise.succeed(text)
                    ws.close().cascadeFailure(to: promise)
                }
            }

            let string = try await promise.futureResult.get()
            #expect(string == "Hello, world!")
        }
    }

    @Test("Test WebSocket 404", .bug("https://github.com/vapor/vapor/issues/1997"))
    func testWebSocket404() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            app.webSocket("bar") { req, ws in
                ws.close(promise: nil)
            }

            try await app.startup()

            let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port)
            await #expect(performing: {
                try await WebSocket.connect(
                    to: "ws://localhost:\(port)/foo",
                    on: app.eventLoopGroup.next()
                ) { _ in  }
            }, throws: { error in
                guard let error = error as? WebSocketClient.Error else {
                    return false
                }
                if case .invalidResponseStatus(let head) = error {
                    return head.status == .notFound
                } else {
                    return false
                }
            })
        }
    }

    @Test("Test WebSocket Server", .bug("https://github.com/vapor/vapor/issues/2009"))
    func testWebSocketServer() async throws {
        try await withApp { app in
            app.webSocket("foo") { req, ws in
                ws.send("foo")
                ws.close(promise: nil)
            }
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            try await app.startup()

            let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port)
            let promise = app.eventLoopGroup.next().makePromise(of: String.self)
            WebSocket.connect(
                to: "ws://localhost:\(port)/foo",
                on: app.eventLoopGroup.next()
            ) { ws in
                // do nothing
                ws.onText { ws, string in
                    promise.succeed(string)
                }
            }.cascadeFailure(to: promise)

            let string = try await promise.futureResult.get()
            #expect(string == "foo")
        }
    }

    @Test("Test Manual Upgrade to WebSocket")
    func testManualUpgradeToWebSocket() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            app.get("foo") { req in
                return req.webSocket { req, ws in
                    ws.send("foo")
                    ws.close(promise: nil)
                }
            }

            try await app.startup()

            let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port)
            let promise = app.eventLoopGroup.next().makePromise(of: String.self)
            WebSocket.connect(
                to: "ws://localhost:\(port)/foo",
                on: app.eventLoopGroup.next()
            ) { ws in
                ws.onText { ws, string in
                    promise.succeed(string)
                }
            }.cascadeFailure(to: promise)

            let string = try await promise.futureResult.get()

            #expect(string == "foo")
        }
    }
}
#endif
