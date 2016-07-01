import XCTest
@testable import Vapor

class EnvironmentTests: XCTestCase {
    static let allTests = [
       ("testEnvironment", testEnvironment),
       ("testDetectEnvironmentHandler", testDetectEnvironmentHandler),
       ("testInEnvironment", testInEnvironment)
    ]

    func testEnvironment() {
        let app = Application()
        XCTAssert(app.config.environment == .development, "Incorrect environment: \(app.config.environment)")
    }

    func testDetectEnvironmentHandler() throws {
        let config = try Config(environment: .custom("xctest"))
        XCTAssert(config.environment == .custom("xctest"), "Incorrect environment: \(config.environment)")
    }

    func testInEnvironment() throws {
        let config = try Config(environment: .custom("xctest"))
        let app = Application(config: config)
        XCTAssert([.custom("xctest")].contains(app.config.environment), "Environment not correctly detected: \(app.config.environment)")
    }
}
