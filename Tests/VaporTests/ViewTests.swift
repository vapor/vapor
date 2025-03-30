import XCTVapor
import XCTest
import Vapor
import NIOCore

final class ViewTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testViewResponse() async throws {
        app.get("view") { req -> View in
            var data = ByteBufferAllocator().buffer(capacity: 0)
            data.writeString("<h1>hello</h1>")
            return View(data: data)
        }

        try await app.testable().test(.GET, "/view") { res async in
            XCTAssertEqual(res.status.code, 200)
            XCTAssertEqual(res.headers.contentType, .html)
            XCTAssertEqual(res.body.string, "<h1>hello</h1>")
        }
    }
}
