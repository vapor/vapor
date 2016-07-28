import XCTest
@testable import Vapor
import Engine

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

        XCTAssertEqual(dc.outputBuffer, "FastServerProvider attempted to overwrite Server.Type.\n")
        XCTAssert(drop.server is SlowServer.Type)
    }

    func testOverride() {
        let dc = DebugConsole()
        let drop = Droplet(console: dc, providers: [
            FastServerProvider.self,
            SlowServerProvider.self
        ])

        XCTAssertEqual(dc.outputBuffer, "SlowServerProvider attempted to overwrite Server.Type.\n")
        XCTAssert(drop.server is FastServer.Type)
    }

    func testInitialized() throws {
        let dc = DebugConsole()

        let fast = try FastServerProvider(config: Config())
        let slow = try SlowServerProvider(config: Config())

        let drop = Droplet(arguments: ["vapor", "serve"], console: dc, initializedProviders: [fast, slow])

        XCTAssertEqual(dc.outputBuffer, "SlowServerProvider attempted to overwrite Server.Type.\n")
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

private final class FastServer: Server {
    var host: String
    var port: Int
    var securityLayer: SecurityLayer
    init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
    }

    func start(responder: HTTPResponder, errors: ServerErrorHandler) throws {

    }
}

private final class FastServerProvider: Provider {
    var provided: Providable

    var afterInitFlag = false
    var beforeServeFlag = false

    init(config: Config) throws {
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

private final class SlowServer: Server {
    var host: String
    var port: Int
    var securityLayer: SecurityLayer
    init(host: String, port: Int, securityLayer: SecurityLayer) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
    }

    func start(responder: HTTPResponder, errors: ServerErrorHandler) throws {

    }
}

private final class SlowServerProvider: Provider {
    var provided: Providable

    var afterInitFlag = false
    var beforeServeFlag = false

    init(config: Config) throws {
        provided = Providable(server: SlowServer.self)
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeServe(_ drop: Droplet) {
        beforeServeFlag = true
    }
}
