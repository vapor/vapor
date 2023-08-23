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

        app.http.server.configuration.port = 8085

        app.webSocket("bar") { req, ws in
            ws.close(promise: nil)
        }

        app.environment.arguments = ["serve"]

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

    ///PMCE additions
    func testWebSocketClient_with_no_pmce_sent_to_server_gets_none_back() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.server.configuration.port = 8085

        app.webSocket("test",
                      maxFrameSize: WebSocketMaxFrameSize.default) { req, webSoc in
            
            webSoc.eventLoop.execute {
                req.logger.info("WebSocket upgrade Complete. PMCE is \(String(describing: webSoc.pmce))")
              
            }
        }

        app.environment.arguments = ["serve"]

        try app.start()

        do {
          
            // connect without PMCE
            try WebSocket.connect(
                to: "ws://localhost:8085/test",
                on: app.eventLoopGroup.next()
            ) { ws in
                XCTAssertNil(ws.pmce, "PMCE shuold be nil")
            }.wait()
        } catch {
          
        }
    }
    
    func testWebSocketClient_with_pmce_sent_to_server_gets_pmce_back() throws {
        
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.server.configuration.port = 8085

        app.webSocket("test",
                      maxFrameSize: WebSocketMaxFrameSize.default) { req, webSoc in
            
        }

        app.environment.arguments = ["serve"]

        try app.start()

        do {
            let deflate = PMCE.PMCEConfig.init(clientCfg: .init(takeover: .noTakeover),
                                                  serverCfg: .init(takeover: .noTakeover))
            try WebSocket.connect(
                to: "ws://localhost:8085/test",
                configuration: .init(pmceConfig: deflate),
                on: app.eventLoopGroup.next()
            ) { ws in
                XCTAssertNotNil(ws.pmce, "PMCE shuold NOT be nil")
            }.wait()
        } catch {
            app.logger.error("\(error.localizedDescription)")
        }
    }
    
    func testLifecycleShutdown() throws {
        let app = Application(.testing)
        app.http.server.configuration.port = 1337

        final class WebSocketManager: LifecycleHandler {
            private let lock: NIOLock
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

        app.environment.arguments = ["serve"]

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
