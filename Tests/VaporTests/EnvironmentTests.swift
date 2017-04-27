import XCTest
@testable import Vapor

class EnvironmentTests: XCTestCase {
    static let allTests = [
       ("testEnvironment", testEnvironment)
    ]

    func testEnvironment() throws {
        let drop = try Droplet()
        XCTAssertEqual(drop.config.environment, .development)
    }
}
