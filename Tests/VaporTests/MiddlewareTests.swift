import XCTVapor

final class MiddlewareTests: XCTestCase {
     func testSecurityHeadersMiddleware() throws {
        let app = Application.create(routes: { r, c in
            r.grouped(SecurityHeadersMiddleware()).get("get") { req -> String in
                return "test"
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory().test(.GET, "/get") { res in
            XCTAssertEqual(res.headers.firstValue(name: .xssProtection), "1; mode=block")
            XCTAssertEqual(res.headers.firstValue(name: .xContentTypeOptions), "nosniff")
            XCTAssertEqual(res.headers.firstValue(name: .xFrameOptions), "sameorigin")
        }
    }
}