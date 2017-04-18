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
        drop.server = ServerFactory<SlowServer>()

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

        var config = Config([:])
        config.arguments = ["vapor", "serve"]
        try config.addProvider(fast)
        try config.addProvider(slow)
        let drop = try Droplet(config, console: DebugConsole())

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
    
    func testDoubleBoot() throws {
        let drop = try Droplet()
        try drop.addProvider(SlowServerProvider.self)
        try drop.addProvider(FastServerProvider.self)
        try drop.addProvider(FastServerProvider.self)
        XCTAssertEqual(drop.providers.count, 2)
        XCTAssert(drop.server is ServerFactory<FastServer>)
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

    init(config: Configs.Config) throws {
    }
    
    func boot(_ config: inout Config) throws {
        
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }

    func boot(_ drop: Droplet) {
        drop.server = ServerFactory<FastServer>()
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
    func boot(_ config: inout Config) throws {
        
    }

    var afterInitFlag = false
    var beforeRunFlag = false

    init(config: Configs.Config) throws {
    }

    func afterInit(_ drop: Droplet) {
        afterInitFlag = true
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }

    func boot(_ drop: Droplet) {
        drop.server = ServerFactory<SlowServer>()
    }
}
