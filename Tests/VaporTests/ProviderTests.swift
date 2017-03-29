import XCTest
@testable import Vapor
import HTTP
import Transport

class ProviderTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testPrecedence", testPrecedence),
        ("testOverride", testOverride),
        ("testInitialized", testInitialized),
        ("testProviderRepository", testProviderRepository),
        ("testCheckoutsDirectory", testCheckoutsDirectory),
    ]

    func testBasic() throws {
        let drop = try Droplet()

        try drop.addProvider(FastServerProvider.self)

        XCTAssert(drop.server is FastServer.Type)
    }

    func testPrecedence() throws {
        let drop = try Droplet()

        drop.console = DebugConsole()
        try drop.addProvider(FastServerProvider.self)
        drop.server = SlowServer.self

        XCTAssert(drop.server is SlowServer.Type)
    }

    func testOverride() throws {
        let drop = try Droplet()

        drop.console = DebugConsole()
        try drop.addProvider(SlowServerProvider.self)
        try drop.addProvider(FastServerProvider.self)

        XCTAssert(drop.server is FastServer.Type)
    }

    func testInitialized() throws {
        let fast = try FastServerProvider(config: Config([:]))
        let slow = try SlowServerProvider(config: Config([:]))

        let drop = try Droplet(arguments: ["vapor", "serve"]) // , console: dc, initializedProviders: [fast, slow]
        drop.console = DebugConsole()
        try drop.addProvider(fast)
        try drop.addProvider(slow)

        XCTAssert(drop.server is SlowServer.Type)

        XCTAssertEqual(fast.beforeRunFlag, false)
        XCTAssertEqual(slow.beforeRunFlag, false)

        background {
            try! drop.runCommands()
        }

        drop.console.wait(seconds: 1)
        XCTAssertEqual(slow.beforeRunFlag, true)
        XCTAssertEqual(fast.beforeRunFlag, true)
    }

    func testProviderRepository() {
        XCTAssertEqual(FastServerProvider.repositoryName, "tests-provider")
    }

    func testCheckoutsDirectory() {
        XCTAssertNil(FastServerProvider.resourcesDir)
        XCTAssertNil(FastServerProvider.viewsDir)
    }
}

// MARK: Utility

// Fast

private final class FastServer: ServerProtocol {
    var host: String
    var port: Int
    var securityLayer: SecurityLayer


    init(hostname: String, port: Transport.Port, _ securityLayer: SecurityLayer) throws {
        host = hostname
        self.port = Int(port)
        self.securityLayer = securityLayer
    }

    func start(
        _ responder: Responder,
        errors: @escaping ServerErrorHandler
    ) throws {
        while true { }
    }
}

private final class FastServerProvider: Provider {
    var beforeRunFlag = false

    init(config: Settings.Config) throws {
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }

    func boot(_ drop: Droplet) {
        drop.server = FastServer.self
    }
}

// Slow

private final class SlowServer: ServerProtocol {
    var host: String
    var port: Int
    var securityLayer: SecurityLayer


    init(hostname: String, port: Transport.Port, _ securityLayer: SecurityLayer) throws {
        host = hostname
        self.port = Int(port)
        self.securityLayer = securityLayer
    }

    func start(
        _ responder: Responder,
        errors: @escaping ServerErrorHandler
    ) throws {
        while true { }
    }
}

private final class SlowServerProvider: Provider {
    var afterInitFlag = false
    var beforeRunFlag = false

    init(config: Settings.Config) throws {
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }

    func boot(_ drop: Droplet) {
        drop.server = SlowServer.self
    }
}
