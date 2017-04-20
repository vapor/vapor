import XCTest
import Vapor
import Sessions
import HTTP

class ConfigTests: XCTestCase {
    func testConfigAvailableType() throws {
        var config = Config([:])
        try config.set("droplet.log", "test")
        config.addConfigurable(log: TestLogger.init, name: "test")
    
        let drop = try Droplet(config)
        XCTAssert(type(of: drop.log) == TestLogger.self)
    }
    
    func testConfigUnavailableType() throws {
        do {
            var config = Config([:])
            try config.set("droplet.log", "test")
        
            let drop = try Droplet(config)
            print(drop)
        } catch ConfigError.unavailable(let value, let key, let file, let available, let type) {
            XCTAssertEqual(value, "test")
            XCTAssertEqual(key, ["log"])
            XCTAssertEqual(file, "droplet")
            XCTAssertEqual(available, ["console"])
            XCTAssert(type == LogProtocol.self)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testMiddlewareOrder() throws {
        var config = Config([:])
        try config.set("droplet.middleware", [
            "date",
            "file",
            "date",
            "error",
            "sessions"
        ])
        
        let drop = try Droplet(config)
        
        guard drop.middleware.count == 5 else {
            XCTFail("Invalid middleware count")
            return
        }
        
        XCTAssert(type(of: drop.middleware[0]) == DateMiddleware.self)
        XCTAssert(type(of: drop.middleware[1]) == FileMiddleware.self)
        XCTAssert(type(of: drop.middleware[2]) == DateMiddleware.self)
        XCTAssert(type(of: drop.middleware[3]) == ErrorMiddleware.self)
        XCTAssert(type(of: drop.middleware[4]) == SessionsMiddleware.self)
    }
    
    func testDependency() throws {
        var config = Config([:])
        try config.set("droplet.log", "test")
        try config.set("droplet.middleware", ["logger"])
        config.addConfigurable(log: TestLogger.init, name: "test")
        config.addConfigurable(middleware: NeedsLoggerMiddleware.init, name: "logger")
        
        let drop = try Droplet(config)
        XCTAssert(type(of: drop.log) == TestLogger.self)
        guard let middleware = drop.middleware.first as? NeedsLoggerMiddleware else {
            XCTFail("Invalid middleware")
            return
        }
        XCTAssert(type(of: middleware.log) == TestLogger.self)
    }

    static let allTests = [
        ("testConfigAvailableType", testConfigAvailableType),
        ("testConfigUnavailableType", testConfigUnavailableType),
        ("testConfigUnavailableType", testConfigUnavailableType),
    ]
}

// MARK: Test Objects

final class TestLogger: LogProtocol, ConfigInitializable {
    var enabled: [LogLevel]
    init(config: Config) throws {
        enabled = []
    }
    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        //
    }
}

final class NeedsLoggerMiddleware: Middleware, ConfigInitializable {
    let log: LogProtocol
    
    init(config: Config) throws {
        self.log = try config.resolveLog()
    }
    
    init(_ log: LogProtocol) {
        self.log = log
    }
    
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        log.info("\(request)")
        return try next.respond(to: request)
    }
}
