import XCTVapor

final class ViewTests: XCTestCase {
    func testViewResponse() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("view") { req -> View in
            var data = ByteBufferAllocator().buffer(capacity: 0)
            data.writeString("<h1>hello</h1>")
            return View(data: data)
        }

        try app.testable().test(.GET, "/view") { res in
            XCTAssertEqual(res.status.code, 200)
            XCTAssertEqual(res.headers.contentType, .html)
            XCTAssertEqual(res.body.string, "<h1>hello</h1>")
        }
    }
}
