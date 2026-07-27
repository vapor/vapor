import XCTVapor
import XCTest
import Vapor
import NIOCore
import Tracing

final class RequestTaskLocalMiddlewareTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testPropagation() async throws {
        app
            .grouped(RequestTaskLocalMiddleware())
            .get("withTaskLocal") { req async throws -> String in
                XCTAssertNotNil(Request.current)
                XCTAssertNoThrow(try Request.requireCurrent)
                return "all good"
            }
        app
            .get("withoutTaskLocal") { req async throws -> String in
                XCTAssertNil(Request.current)
                do {
                    _ = try Request.requireCurrent
                    XCTFail("Expected an error to be thrown")
                } catch let error as Abort {
                    XCTAssertEqual(error.status, .internalServerError)
                    XCTAssertEqual(error.reason, "Task local Vapor.Request not found, make sure you added RequestTaskLocalMiddleware.")
                }
                return "not found"
            }
        try await app
            .testable()
            .test(.GET, "/withTaskLocal") { res async in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "all good")
            }
            .test(.GET, "/withoutTaskLocal") { res async in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "not found")
            }
    }
}
