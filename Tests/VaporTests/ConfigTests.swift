import XCTest
import Vapor
import Sessions
import HTTP
import Console

class ConfigTests: XCTestCase {
    override func setUp() {
        Node.fuzzy = [JSON.self, Node.self]
    }
    
    func testConfigAvailableType() throws {
        var config = Config([:])
        try config.set("droplet.log", "test")
        
        var services = Services.default()
        services.register(TestLogger.self)
    
        let drop = try Droplet(config, services)
        try XCTAssert(drop.log() is TestLogger)
     }
    
    func testMiddlewareOrder() throws {
        var config = Config([:])
        try config.set("droplet.sessions", "memory")
        try config.set("droplet.middleware", [
            "date",
            "file",
            "date",
            "error",
            "sessions",
            "date-extra"
        ])
        
        let extra = DateMiddleware()
        
        var services = Services.default()
        services.instance(extra, name: "date-extra")
        
        let drop = try! Droplet(config, services)
        let middleware = try! drop.middleware()
        guard middleware.count == 6 else {
            XCTFail("Invalid middleware count")
            return
        }
        
        XCTAssert(type(of: middleware[0]) == DateMiddleware.self)
        XCTAssert(type(of: middleware[1]) == FileMiddleware.self)
        XCTAssert(type(of: middleware[2]) == DateMiddleware.self)
        XCTAssert(type(of: middleware[3]) == ErrorMiddleware.self)
        XCTAssert(type(of: middleware[4]) == SessionsMiddleware.self)
        XCTAssert(type(of: middleware[5]) == DateMiddleware.self)
    }
    
    func testDependency() throws {
        var config = Config.default()
        try config.set("droplet.log", "test")
        try config.set("droplet.middleware", ["logger"])
        
        var services = Services.default()
        services.register(TestLogger.self)
        services.register(NeedsLoggerMiddleware.self)
        
        let drop = try! Droplet(config, services)
        try! XCTAssert(type(of: drop.make(LogProtocol.self)) == TestLogger.self)
        guard let middleware = try drop.make([Middleware.self]).first as? NeedsLoggerMiddleware else {
            XCTFail("Invalid middleware")
            return
        }
        XCTAssert(type(of: middleware.log) == TestLogger.self)
    }
 
    func testServices() throws {
        var config = Config()
        try config.set("droplet.console", "my-terminal")
        try config.set("droplet.log", "test")

        var services = Services.default()
        services.register(Terminal.self)
        services.register(TestLogger.self)
        
        let term = Terminal(arguments: ["vapor"])
        services.instance(term, name: "my-terminal")
        
        let drop = try! Droplet(config, services)
        
        let console = try! drop.make(ConsoleProtocol.self)
        console.print("console")
        let log = try! drop.make(LogProtocol.self)
        let log2 = try! drop.make(LogProtocol.self)
        log.warning("hi")
        print(log === log2)
        print(console === term)
        if let cl = log as? ConsoleLogger {
            print(cl.console === console)
        }
        if let cl = log2 as? ConsoleLogger {
            print(cl.console === console)
        }
    }
    
    static let allTests = [
        ("testConfigAvailableType", testConfigAvailableType),
        ("testServices", testServices),
        ("testMiddlewareOrder", testMiddlewareOrder),
        ("testDependency", testDependency)
    ]
}

// MARK: Test Objects


final class TestLogger: LogProtocol, Service {
    var enabled: [LogLevel]  = []
    
    static var serviceName: String {
        return "test"
    }

    static func makeService(for drop: Droplet) throws -> TestLogger? {
        return .init()
    }

    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        //
    }
}

final class NeedsLoggerMiddleware: Middleware, Service {
    let log: LogProtocol
    
    static var serviceName: String {
        return "logger"
    }

    static func makeService(for drop: Droplet) throws -> NeedsLoggerMiddleware? {
        return try .init(drop.make(LogProtocol.self))
    }
    
    init(_ log: LogProtocol) {
        self.log = log
    }
    
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        log.info("\(request)")
        return try next.respond(to: request)
    }
}
