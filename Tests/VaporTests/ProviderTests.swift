import XCTest
@testable import Vapor
import HTTP
import Transport

class ProviderTests: XCTestCase {
    func testBasic() throws {
        var config = Config.default()
        try config.set("droplet.server", "fast")
        
        var services = Services.default()
        services.provider(FastServerProvider.self)
        
        let drop = try! Droplet(config, services)
        try! XCTAssert(drop.server() is ServerFactory<FastServer>)
    }

    func testPrecedence() throws {
        var config = Config.default()
        try config.set("droplet.server", "fast")
        
        var services = Services.default()
        services.provider(FastServerProvider.self)
        services.instance(DebugConsole(), name: "debug")
        
        let drop = try! Droplet(config, services)
        try! XCTAssert(drop.server() is ServerFactory<FastServer>)
    }

    func testOverride() throws {
        var config = Config.default()
        try config.set("droplet.server", "fast")
        
        var services = Services.default()
        services.provider(SlowServerProvider.self)
        services.provider(FastServerProvider.self)
        services.instance(DebugConsole(), name: "debug")
        
        let drop = try! Droplet(config, services)
        try! XCTAssert(drop.server() is ServerFactory<FastServer>)
    }

    func testInitialized() throws {
        var config = Config.default()
        try config.set("droplet.server", "slow")
        config.arguments = ["vapor", "serve"]
        
        let fast = try FastServerProvider(config: config)
        let slow = try SlowServerProvider(config: config)

        var services = Services.default()
        services.provider(fast)
        services.provider(slow)
        services.instance(DebugConsole(), name: "debug")

        let drop = try! Droplet(config, services)
        
        try! print(drop.server())
        try! XCTAssert(drop.server() is ServerFactory<SlowServer>)

        XCTAssertEqual(fast.beforeRunFlag, false)
        XCTAssertEqual(slow.beforeRunFlag, false)

        background {
            try! drop.runCommands()
        }

        try! drop.console().wait(seconds: 1)
        XCTAssertEqual(slow.beforeRunFlag, true)
        XCTAssertEqual(fast.beforeRunFlag, true)
    }

    func testProviderRepository() {
        XCTAssertEqual(FastServerProvider.repositoryName, "fast-server")
    }

    func testCheckoutsDirectory() {
        XCTAssertNil(FastServerProvider.providedDirectory)
    }
    
    func testDoubleBoot() throws {
        var config = Config.default()
        try config.set("droplet.server", "fast")
        
        var services = Services.default()
        services.provider(SlowServerProvider.self)
        services.provider(FastServerProvider.self)
        services.provider(FastServerProvider.self)
        
        let drop = try Droplet(config, services)
        XCTAssertEqual(drop.providers.count, 2)
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

private final class FastServerProvider: Provider {
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

    func boot(_ drop: Droplet) {

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

private final class SlowServerProvider: Provider {
    static let repositoryName = "slow-server"
    var beforeRunFlag = false

    init(config: Configs.Config) throws {
        
    }

    func beforeRun(_ drop: Droplet) {
        beforeRunFlag = true
    }
    
    func register(_ services: inout Services) throws {
        services.register(ServerFactory<SlowServer>.self)
    }

    func boot(_ drop: Droplet) {
        
    }
}
