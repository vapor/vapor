import Vapor
import XCTVapor
import XCTest

final class ApplicationCreationTests: XCTestCase {
    var app: Application!

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testCreateAsyncDefaultLogger() async throws {
        app = try await Application.make(.testing)
        XCTAssertEqual(app.logger.label, "codes.vapor.application")
    }

    func testCreateAsyncCustomLogger() async throws {
        let logger = Logger(label: "custom")
        app = try await Application.make(.testing, logger: logger)
        XCTAssertEqual(app.logger.label, "custom")
    }
}
