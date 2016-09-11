import XCTest
@testable import Vapor
import HTTP
import Transport

class ProviderTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
    ]

    func testBasic() {
        let drop = Droplet(providers: [FastServerProvider.self])
        XCTAssert(drop.server is FastServer.Type)
    }

    func testPrecedence() {
        let dc = DebugConsole()
        let drop = Droplet(server: SlowServer.self, console: dc, providers: [FastServerProvider.self])

        XCTAssert(dc.outputBuffer.contains("FastServerProvider attempted to overwrite ServerProtocol.Type.\n"))
        XCTAssert(drop.server is SlowServer.Type)
    }

    func testOverride() {
        let dc = DebugConsole()
        let drop = Droplet(console: dc, providers: [
            FastServerProvider.self,
            SlowServerProvider.self
        ])

        XCTAssert(dc.outputBuffer.contains("SlowServerProvider attempted to overwrite ServerProtocol.Type.\n"))
        XCTAssert(drop.server is FastServer.Type)
    }

    func testInitialized() throws {
        let dc = DebugConsole()

        let fast = try FastServerProvider(config: Config([:]))
        let slow = try SlowServerProvider(config: Config([:]))

        let drop = Droplet(arguments: ["vapor", "serve"], console: dc, initializedProviders: [fast, slow])

        XCTAssert(dc.outputBuffer.contains("SlowServerProvider attempted to overwrite ServerProtocol.Type.\n"))
        XCTAssert(drop.server is FastServer.Type)

        XCTAssertEqual(fast.afterInitFlag, true)
        XCTAssertEqual(fast.beforeServeFlag, false)
        XCTAssertEqual(slow.afterInitFlag, true)
        XCTAssertEqual(slow.beforeServeFlag, false)

        try drop.runCommands()

        XCTAssertEqual(slow.beforeServeFlag, true)
        XCTAssertEqual(fast.beforeServeFlag, true)
    }
}

// MARK: Utility

// Fast

private final class FastServer: ServerProtocol {
    var host: String
    var port: Int
    var securityLayer: SecurityLayer
    var middleware: [Middleware]
    init(host: String, port: Int, securityLayer: SecurityLayer, middleware: [Middleware]) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
        self.middleware = middleware
    }

    func start(responder: Responder, errors: @escaping ServerErrorHandler) throws {

    }
}

private final class FastServerProvider: Provider {
    var provided: Providable

    var afterInitFlag = false
    var beforeServeFlag = false

    init(config: Settings.Config) throws {
        provided = Providable(server: FastServer.self)
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeServe(_ drop: Droplet) {
        beforeServeFlag = true
    }
}

// Slow

private final class SlowServer: ServerProtocol {
    var host: String
    var port: Int
    var securityLayer: SecurityLayer
    var middleware: [Middleware]

    init(host: String, port: Int, securityLayer: SecurityLayer, middleware: [Middleware]) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
        self.middleware = middleware
    }

    func start(responder: Responder, errors: @escaping ServerErrorHandler) throws {

    }
}

private final class SlowServerProvider: Provider {
    var provided: Providable

    var afterInitFlag = false
    var beforeServeFlag = false

    init(config: Settings.Config) throws {
        provided = Providable(server: SlowServer.self)
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeServe(_ drop: Droplet) {
        beforeServeFlag = true
    }
}
