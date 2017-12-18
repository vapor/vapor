import Async
import Dispatch
import Service
import XCTest

class ServiceTests: XCTestCase {
    func testHappyPath() throws {
        let config = Config()
        var services = Services()
        services.register(PrintLog.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try container.make(Log.self, for: ServiceTests.self)
        XCTAssert(log is PrintLog)
    }

    func testMultiple() throws {
        var config = Config()
        config.prefer(PrintLog.self, for: Log.self)

        var services = Services()
        services.register(PrintLog.self)
        services.register(AllCapsLog.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try container.make(Log.self, for: ServiceTests.self)
        XCTAssert(log is PrintLog)
    }

    func testTagged() throws {
        var config = Config()
        config.prefer(PrintLog.self, tagged: "foo", for: Log.self)

        var services = Services()
        services.register(PrintLog.self)
        services.register(AllCapsLog.self)

        let foo = PrintLog()
        services.register(supports: [Log.self], tag: "foo", foo)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try! container.make(Log.self, for: ServiceTests.self)
        XCTAssert(log is PrintLog)
    }
    
    func testTagDisambiguation() throws {
        var config = Config()
        config.prefer(ConfigurableLog.self, tagged: "foo1", for: Log.self)
        
        var services = Services()
        services.register(Log.self, tag: "foo1") { _ -> ConfigurableLog in ConfigurableLog(config: "foo1") }
        services.register(Log.self, tag: "foo2") { _ -> ConfigurableLog in ConfigurableLog(config: "foo2") }
        
        let container = BasicContainer(
        	config: config,
         	environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try container.make(Log.self, for: ServiceTests.self)
        
        XCTAssertEqual((log as? ConfigurableLog)?.myConfig, "foo1")
    }

    func testClient() throws {
        var config = Config()
        config.prefer(PrintLog.self, for: Log.self, neededBy: ServiceTests.self)

        var services = Services()
        services.register(PrintLog.self)
        services.register(AllCapsLog.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try! container.make(Log.self, for: ServiceTests.self)
        XCTAssert(log is PrintLog)
    }

    func testSpecific() throws {
        let config = Config()
        var services = Services()
        services.register(PrintLog.self)
        services.register(AllCapsLog.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try container.make(AllCapsLog.self, for: ServiceTests.self)
        XCTAssert(type(of: log) == AllCapsLog.self)
    }

    func testProvider() throws {
        let config = Config()
        var services = Services()
        try services.register(AllCapsProvider())

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        let log = try container.make(AllCapsLog.self, for: ServiceTests.self)
        XCTAssert(type(of: log) == AllCapsLog.self)
    }

    func testRequire() throws {
        var config = Config()
        config.require(PrintLog.self, for: Log.self)

        var services = Services()
        services.register(AllCapsLog.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )
        XCTAssertThrowsError(_ = try container.make(Log.self, for: ServiceTests.self), "Should not have resolved")
    }

    static var allTests = [
        ("testHappyPath", testHappyPath),
        ("testMultiple", testMultiple),
        ("testTagged", testTagged),
        ("testTagDisambiguation", testTagDisambiguation),
        ("testClient", testClient),
        ("testSpecific", testSpecific),
        ("testProvider", testProvider),
        ("testRequire", testRequire),
    ]
}


