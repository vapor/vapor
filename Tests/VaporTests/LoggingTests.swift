import XCTVapor
import Vapor
import XCTest

final class LoggingTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testChangeRequestLogLevel() throws {
        app.get("trace") { req -> String in
            req.logger.logLevel = .trace
            req.logger.trace("foo")
            return "done"
        }

        try app.testable().test(.GET, "trace") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "done")
        }
    }
}
