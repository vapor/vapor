import Vapor
import XCTVapor
import XCTest
import Logging

final class ApplicationCreationTests: XCTestCase {
    var app: Application!

    override func tearDown() async throws {
        try await app.shutdown()
    }

    func testCreateAsyncDefaultLogger() async throws {
        app = try await Application(.testing)
        XCTAssertEqual(app.logger.label, "codes.vapor.application")
    }

    func testCreateAsyncCustomLogger() async throws {
        let logger = Logger(label: "custom")
        app = try await Application(.testing, services: .init(logger: .provided(logger)))
        XCTAssertEqual(app.logger.label, "custom")
    }
}
