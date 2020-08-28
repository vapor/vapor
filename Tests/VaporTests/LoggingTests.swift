import XCTVapor

final class LoggingTests: XCTestCase {
    func testChangeRequestLogLevel() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

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
