import XCTest
@testable import Vapor

class EnvironmentTests: XCTestCase {
    static let allTests = [
       ("testEnvironment", testEnvironment)
    ]

    func testEnvironment() throws {
        let drop = try Droplet()
        XCTAssert(drop.environment == .development, "Incorrect environment: \(drop.environment)")
    }
}
