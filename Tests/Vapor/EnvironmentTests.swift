import XCTest
@testable import Vapor

class EnvironmentTests: XCTestCase {
    static let allTests = [
       ("testEnvironment", testEnvironment),
       ("testDetectEnvironmentHandler", testDetectEnvironmentHandler),
       ("testInEnvironment", testInEnvironment)
    ]

    func testEnvironment() {
        let drop = Droplet()
        XCTAssert(drop.config.environment == .development, "Incorrect environment: \(drop.config.environment)")
    }

    func testDetectEnvironmentHandler() throws {
        let config = try Config(environment: .custom("xctest"))
        XCTAssert(config.environment == .custom("xctest"), "Incorrect environment: \(config.environment)")
    }

    func testInEnvironment() throws {
        let config = try Config(environment: .custom("xctest"))
        let drop = Droplet(config: config)
        XCTAssert([.custom("xctest")].contains(drop.config.environment), "Environment not correctly detected: \(drop.config.environment)")
    }
}
