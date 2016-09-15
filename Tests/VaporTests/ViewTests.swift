import XCTest
import Leaf
import Core
@testable import Vapor

class ViewTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testViewBytes", testViewBytes),
        ("testViewResponse", testViewResponse),
    ]

    func testBasic() throws {
        let r = TestRenderer(viewsDir: "ferret")
        r.views["foo"] = "42".bytes

        let view = try r.make("foo")
        XCTAssertEqual(view.data.string, "42")


        let view2 = try r.make("foo", "context")
        XCTAssertEqual(view2.data.string, "42")
    }

    func testViewBytes() throws {
        let view = try View(bytes: "42".bytes)
        XCTAssertEqual(try view.makeBytes(), "42".bytes)
    }


    func testViewResponse() throws {
        let view = try View(bytes: "42 🚀".bytes)
        let response = view.makeResponse()

        XCTAssertEqual(response.headers["content-type"], "text/html; charset=utf-8")
        XCTAssertEqual(try response.bodyString(), "42 🚀")
    }

    func testLeafRenderer() throws {
        var directory = #file.components(separatedBy: "/")
        let file = directory.removeLast()
        let renderer = LeafRenderer(viewsDir: directory.joined(separator: "/"))
        let result = try renderer.make(file, [])
        XCTAssert(result.data.string.contains("meta string"))
    }
}
