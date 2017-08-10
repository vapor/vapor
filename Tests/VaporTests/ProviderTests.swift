import XCTest
@testable import Vapor
import HTTP
import Transport
import Console
import Configs
import Service

class ProviderTests: XCTestCase {
    func testBasic() throws {
        var config = Config.default()
        try config.set("droplet", "server", to: "fast")
        
        var services = Services.default()
        try services.register(FastServerProvider.self, using: config)
        
        let drop = try Droplet(config, services)
        try XCTAssert(drop.server() is ServerFactory<FastServer>)
    }

    func testPrecedence() throws {
        var config = Config.default()
        try config.set("droplet", "server", to: "fast")
        
        var services = Services.default()
        try services.register(FastServerProvider.self, using: config)
        services.register(DebugConsole(), name: "debug", supports: [ConsoleProtocol.self])
        
        let drop = try Droplet(config, services)
        try XCTAssert(drop.server() is ServerFactory<FastServer>)
    }

    func testOverride() throws {
        var config = Config.default()
        try config.set("droplet", "server", to: "fast")
        
        var services = Services.default()
        try services.register(SlowServerProvider.self, using: config)
        try services.register(FastServerProvider.self, using: config)
        services.register(DebugConsole(), name: "debug", supports: [ConsoleProtocol.self])
        
        let drop = try Droplet(config, services)
        try XCTAssert(drop.server() is ServerFactory<FastServer>)
    }

    func testInitialized() throws {
        var config = Config.default()
        try config.set("droplet", "server", to: "slow")
        config.arguments = ["vapor", "serve"]
        
        let fast = try FastServerProvider(config: config)
        let slow = try SlowServerProvider(config: config)

        var services = Services.default()
        try services.register(fast)
        try services.register(slow)
        services.register(DebugConsole(), name: "debug", supports: [ConsoleProtocol.self])

        let drop = try Droplet(config, services)
        
        try print(drop.server())
        try XCTAssert(drop.server() is ServerFactory<SlowServer>)

        XCTAssertEqual(fast.beforeRunFlag, false)
        XCTAssertEqual(slow.beforeRunFlag, false)

        background {
            try! drop.runCommands()
        }
    }

    func testProviderRepository() {
        XCTAssertEqual(FastServerProvider.repositoryName, "fast-server")
    }

    func testCheckoutsDirectory() {
        XCTAssertNil(FastServerProvider.providedDirectory)
    }
    
    func testDoubleBoot() throws {
        var config = Config.default()
        try config.set("droplet", "server", to: "fast")
        
        var services = Services.default()
        try services.register(SlowServerProvider.self, using: config)
        try services.register(FastServerProvider.self, using: config)
        try services.register(FastServerProvider.self, using: config)
        
        let drop = try Droplet(config, services)
        XCTAssertEqual(drop.services.providers.count, 2)
        try XCTAssert(drop.server() is ServerFactory<FastServer>)
    }
    
    static let allTests = [
        ("testBasic", testBasic),
        ("testPrecedence", testPrecedence),
        ("testOverride", testOverride),
        ("testInitialized", testInitialized),
        ("testProviderRepository", testProviderRepository),
        ("testCheckoutsDirectory", testCheckoutsDirectory),
    ]
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
    
    static var serviceName: String { return "fast" }
}

private final class FastServerProvider: Provider, ConfigInitializable {
    static let repositoryName = "fast-server"
    var beforeRunFlag = false

    init(config: Configs.Config) throws {
    }
    
    func register(_ services: inout Services) throws {
        services.register(ServerFactory<FastServer>.self)
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }

    func boot(_ drop: Container) {

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
    
    static var serviceName: String { return "slow" }
}

private final class SlowServerProvider: Provider, ConfigInitializable {
    static let repositoryName = "slow-server"
    var beforeRunFlag = false

    init(config: Configs.Config) throws {
        
    }
    
    func register(_ services: inout Services) throws {
        services.register(ServerFactory<SlowServer>.self)
    }

    func boot(_ drop: Container) {
        
    }
}
