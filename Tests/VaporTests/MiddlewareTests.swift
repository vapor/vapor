import Vapor // not @testable to ensure Middleware classes are public 
import XCTest

class MiddlewareTests: XCTestCase {
    static let allTests = [
        ("testBundledMiddleware", testBundledMiddleware)
    ]

    func testBundledMiddleware() throws {
        let drop = Droplet()

        let bundledMiddleware: [Middleware] = [
            FileMiddleware(workDir: drop.workDir),
            SessionMiddleware(sessions: drop.sessions),
            ValidationMiddleware(),
            DateMiddleware(),
            TypeSafeErrorMiddleware(),
            AbortMiddleware()
        ]

        for middleware in bundledMiddleware {
            drop.middleware = drop.middleware.filter() { (type(of: $0) != type(of: middleware) }
        }

        XCTAssert(drop.middleware.count == 0, "Bundled middleware not all removed")

        for middleware in bundledMiddleware {
            drop.middleware += middleware
        }

        XCTAssert(drop.middleware.count == bundledMiddleware.count, "Bundled middleware not all added")
    }
}
