import Vapor
import NIOConcurrencyHelpers
import XCTest
import WebSocketKit
import NIOPosix

final class WebSocketTests: XCTestCase {
    func testWebSocketClient() throws {
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
        let string = try WebSocket.connect(
            to: "ws://localhost:\(port)/echo",
            on: elg.next()
        ) { ws in
            ws.send("Hello, world!")
            ws.onText { ws, text in
                promise.succeed(text)
                ws.close().cascadeFailure(to: promise)
            }
        }.flatMap {
            return promise.futureResult
        }.flatMapError { error in
            promise.fail(error)
            return promise.futureResult
        }.wait()
        XCTAssertEqual(string, "Hello, world!")
    }


    // https://github.com/vapor/vapor/issues/1997
    func testWebSocket404() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.webSocket("bar") { req, ws in
            ws.close(promise: nil)
        }

        app.http.server.configuration.port = 0
        app.environment.arguments = ["serve"]

        try app.start()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        do {
            try WebSocket.connect(
                to: "ws://localhost:\(port)/foo",
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
        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0

        try app.start()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
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

        try XCTAssertEqual(promise.futureResult.wait(), "foo")
    }

    func testManualUpgradeToWebSocket() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.server.configuration.port = 0

        app.get("foo") { req in
            return req.webSocket { req, ws in
                ws.send("foo")
                ws.close(promise: nil)
            }
        }

        app.environment.arguments = ["serve"]

        try app.start()
        
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let promise = app.eventLoopGroup.next().makePromise(of: String.self)
        WebSocket.connect(
            to: "ws://localhost:\(port)/foo",
            on: app.eventLoopGroup.next()
        ) { ws in
            ws.onText { ws, string in
                promise.succeed(string)
            }
        }.cascadeFailure(to: promise)

        try XCTAssertEqual(promise.futureResult.wait(), "foo")
    }

    override class func setUp() {
        XCTAssertTrue(isLoggingConfigured)
    }
}

extension Vapor.WebSocket: Swift.Hashable {
    public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
