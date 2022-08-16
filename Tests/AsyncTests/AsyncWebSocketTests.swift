#if canImport(_Concurrency)
import XCTVapor
import Vapor

final class AsyncWebSocketTests: XCTestCase {
    func testWebSocketClient() async throws {
        let server = Application(.testing)

        server.http.server.configuration.port = 0

        server.webSocket("echo") { req, ws in
            ws.onText { ws.send($1) }
        }
        server.environment.arguments = ["serve"]
        try server.start()

        defer {
            server.shutdown()
        }

        guard let localAddress = server.http.server.shared.localAddress, let port = localAddress.port else {
            XCTFail("couldn't get port from \(server.http.server.shared.localAddress.debugDescription)")
            return
        }

        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let promise = elg.next().makePromise(of: String.self)
        try await WebSocket.connect(
            to: "ws://localhost:\(port)/echo",
            on: elg.next()
        ) { ws in
            ws.send("Hello, world!")
            ws.onText { ws, text in
                promise.succeed(text)
                ws.close().cascadeFailure(to: promise)
            }
        }

        let string = try await promise.futureResult.get()
        XCTAssertEqual(string, "Hello, world!")
    }


    // https://github.com/vapor/vapor/issues/1997
    func testWebSocket404() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.server.configuration.port = 8085

        app.webSocket("bar") { req, ws in
            ws.close(promise: nil)
        }

        app.environment.arguments = ["serve"]

        try app.start()

        do {
            try await WebSocket.connect(
                to: "ws://localhost:8085/foo",
                on: app.eventLoopGroup.next()
            ) { _ in  }
            XCTFail("should have failed")
        } catch {
            // pass
        }
    }

    // https://github.com/vapor/vapor/issues/2009
    func testWebSocketServer() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.webSocket("foo") { req, ws in
            ws.send("foo")
            ws.close(promise: nil)
        }
        app.environment.arguments = ["serve"]

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

        let string = try await promise.futureResult.get()
        XCTAssertEqual(string, "foo")
    }

    func testManualUpgradeToWebSocket() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.server.configuration.port = 8080

        app.get("foo") { req in
            return req.webSocket { req, ws in
                ws.send("foo")
                ws.close(promise: nil)
            }
        }

        app.environment.arguments = ["serve"]

        try app.start()
        let promise = app.eventLoopGroup.next().makePromise(of: String.self)
        WebSocket.connect(
            to: "ws://localhost:8080/foo",
            on: app.eventLoopGroup.next()
        ) { ws in
            ws.onText { ws, string in
                promise.succeed(string)
            }
        }.cascadeFailure(to: promise)

        let string = try await promise.futureResult.get()

        XCTAssertEqual(string, "foo")
    }
}
#endif
