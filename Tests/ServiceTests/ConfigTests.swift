import Async
import Dispatch
import Service
import XCTest

class ConfigTests: XCTestCase {
    /// Tests that BCryptConfig can be added as an instance
    func testBCryptConfig() throws {
        let config = Config()

        var services = Services()
        services.register(BCryptHasher.self)

        let bcryptConfig = BCryptConfig(cost: 4)
        services.register(bcryptConfig)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )

        let hasher = try container.make(Hasher.self, for: ConfigTests.self)
        XCTAssertEqual(hasher.hash("foo"), "$2y:4:foo")
    }

    /// Tests BCryptConfig can be added as a ServiceType
    func testBCryptConfigType() throws {
        let config = Config()
        var services = Services()
        services.register(BCryptHasher.self)
        services.register(BCryptConfig.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )

        let hasher = try container.make(Hasher.self, for: ConfigTests.self)
        XCTAssertEqual(hasher.hash("foo"), "$2y:12:foo")
    }

    /// Tests lack of BCryptConfig results correct error message
    func testBCryptConfigError() throws {
        let config = Config()
        var services = Services()
        services.register(BCryptHasher.self)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )

        do {
            _ = try container.make(Hasher.self, for: ConfigTests.self)
            XCTFail("No error thrown")
        } catch let error as ServiceError {
            XCTAssertEqual(error.reason, "No services are available for 'BCryptConfig'")
        }
    }

    /// Tests too many BCryptConfigs registered
    func testBCryptConfigTooManyError() throws {
        let config = Config()
        var services = Services()
        services.register(BCryptHasher.self)

        let bcryptConfig4 = BCryptConfig(cost: 4)
        services.register(bcryptConfig4)
        let bcryptConfig5 = BCryptConfig(cost: 5)
        services.register(bcryptConfig5)

        let container = BasicContainer(
            config: config,
            environment: .production,
            services: services,
            on: DispatchEventLoop(label: "unit-test")
        )

        let hasher = try container.make(Hasher.self, for: ConfigTests.self)
        XCTAssertEqual(hasher.hash("foo"), "$2y:5:foo")
    }

    static let allTests = [
        ("testBCryptConfig", testBCryptConfig),
        ("testBCryptConfigType", testBCryptConfigType),
        ("testBCryptConfigError", testBCryptConfigError),
        ("testBCryptConfigTooManyError", testBCryptConfigTooManyError),
    ]
}
