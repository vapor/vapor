import XCTest
@testable import Vapor
import HTTP
import Transport

class ProviderTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
    ]

    func testBasic() throws {
        let drop = Droplet()

        try drop.add(FastServerProvider.self)

        XCTAssert(drop.server is FastServer.Type)
    }

    func testPrecedence() throws {
        let drop = Droplet()

        drop.console = DebugConsole()
        try drop.add(FastServerProvider.self)
        drop.server = SlowServer.self

        XCTAssert(drop.server is SlowServer.Type)
    }

    func testOverride() throws {
        let drop = Droplet()

        drop.console = DebugConsole()
        try drop.add(SlowServerProvider.self)
        try drop.add(FastServerProvider.self)

        XCTAssert(drop.server is FastServer.Type)
    }

    func testInitialized() throws {
        let fast = try FastServerProvider(config: Config([:]))
        let slow = try SlowServerProvider(config: Config([:]))

        let drop = Droplet(arguments: ["vapor", "serve"]) // , console: dc, initializedProviders: [fast, slow]
        drop.console = DebugConsole()
        drop.add(fast)
        drop.add(slow)

        XCTAssert(drop.server is SlowServer.Type)

        XCTAssertEqual(fast.afterInitFlag, true)
        XCTAssertEqual(fast.beforeRunFlag, false)
        XCTAssertEqual(slow.afterInitFlag, true)
        XCTAssertEqual(slow.beforeRunFlag, false)

        try drop.runCommands()

        XCTAssertEqual(slow.beforeRunFlag, true)
        XCTAssertEqual(fast.beforeRunFlag, true)
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
    var beforeRunFlag = false

    init(config: Settings.Config) throws {
        provided = Providable(server: FastServer.self)
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
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
    var beforeRunFlag = false

    init(config: Settings.Config) throws {
        provided = Providable(server: SlowServer.self)
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }
}
