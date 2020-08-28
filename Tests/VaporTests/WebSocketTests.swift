import Vapor
import XCTest

final class WebSocketTests: XCTestCase {
    func testWebSocketClient() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("ws") { req -> EventLoopFuture<String> in
            let promise = req.eventLoop.makePromise(of: String.self)
            return WebSocket.connect(
                to: "ws://echo.websocket.org/",
                on: req.eventLoop
            ) { ws in
                ws.send("Hello, world!")
                ws.onText { ws, text in
                    promise.succeed(text)
                    ws.close().cascadeFailure(to: promise)
                }
            }.flatMap {
                return promise.futureResult
            }
        }

        try app.testable().test(.GET, "/ws") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        }
    }


    // https://github.com/vapor/vapor/issues/1997
    func testWebSocket404() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.http.server.configuration.port = 8085

        app.webSocket("bar") { req, ws in
            ws.close(promise: nil)
        }

        try app.start()

        do {
            try WebSocket.connect(
                to: "ws://localhost:8085/foo",
                on: app.eventLoopGroup.next()
            ) { _ in  }.wait()
            XCTFail("should have failed")
        } catch {
            // pass
        }
    }

    // https://github.com/vapor/vapor/issues/2009
    func testWebSocketServer() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }
        app.webSocket("foo") { req, ws in
            ws.send("foo")
            ws.close(promise: nil)
        }

        try app.start()
        let promise = app.eventLoopGroup.next().makePromise(of: String.self)
        WebSocket.connect(
            to: "ws://localhost:8080/foo",
            on: app.eventLoopGroup.next()
        ) { ws in
            // do nothing
            ws.onText { ws, string in
                promise.succeed(string)
            }
        }.cascadeFailure(to: promise)

        try XCTAssertEqual(promise.futureResult.wait(), "foo")
    }

    func testLifecycleShutdown() throws {
        let app = Application(.detect(default: .testing))
        app.http.server.configuration.port = 1337

        final class WebSocketManager: LifecycleHandler {
            private let lock: Lock
            private var connections: Set<WebSocket>

            init() {
                self.lock = .init()
                self.connections = .init()
            }

            func track(_ ws: WebSocket) {
                self.lock.lock()
                defer { self.lock.unlock() }
                self.connections.insert(ws)
                ws.onClose.whenComplete { _ in
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    self.connections.remove(ws)
                }
            }

            func broadcast(_ message: String) {
                self.lock.lock()
                defer { self.lock.unlock() }
                for ws in self.connections {
                    ws.send(message)
                }
            }

            /// Closes all active WebSocket connections
            func shutdown(_ app: Application) {
                self.lock.lock()
                defer { self.lock.unlock() }
                app.logger.debug("Shutting down \(self.connections.count) WebSocket(s)")
                try! EventLoopFuture<Void>.andAllSucceed(
                    self.connections.map { $0.close() } ,
                    on: app.eventLoopGroup.next()
                ).wait()
            }
        }

        let webSockets = WebSocketManager()
        app.lifecycle.use(webSockets)

        app.webSocket("watcher") { req, ws in
            webSockets.track(ws)
            ws.send("hello")
        }

        try app.start()

        let clientGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try! clientGroup.syncShutdownGracefully() }
        let connectPromise = app.eventLoopGroup.next().makePromise(of: WebSocket.self)
        WebSocket.connect(to: "ws://localhost:1337/watcher", on: clientGroup) { ws in
            connectPromise.succeed(ws)
        }.cascadeFailure(to: connectPromise)

        let ws = try connectPromise.futureResult.wait()
        app.shutdown()
        try ws.onClose.wait()
    }

    override class func setUp() {
        XCTAssertTrue(isLoggingConfigured)
    }
}

extension WebSocket: Hashable {
    public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
