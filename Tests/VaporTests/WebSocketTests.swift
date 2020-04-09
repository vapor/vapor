import Vapor
import XCTest

final class WebSocketTests: XCTestCase {
    func testWebSocketClient() throws {
        let app = Application(.testing)
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
        let app = Application(.testing)
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
        let app = Application(.testing)
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
}
