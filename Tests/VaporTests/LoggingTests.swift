import Vapor
import VaporTesting
import Testing

@Suite("Logging Tests")
struct LoggingTests {
    @Test("Test Changing Request Log Level")
    func testChangeRequestLogLevel() async throws {
        try await withApp { app in
            app.get("trace") { req -> String in
                req.logger.logLevel = .trace
                req.logger.trace("foo")
                return "done"
            }

            try await app.testing().test(.get, "trace") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "done")
            }
        }
    }
}
