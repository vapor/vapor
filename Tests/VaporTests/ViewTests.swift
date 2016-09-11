import XCTest
import Leaf
@testable import Vapor

class ViewTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic)
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
    
    func testLeafLocalization() throws {
        // Get the localization
        #if os(Linux)
            let localization = LocalizationTests(name: "LocalizationTests").localization
        #else
            let localization = LocalizationTests().localization
        #endif
        
        // Create a localized Leaf renderer and check its value
        let r = LeafRenderer(viewsDir: "ferret", localization: localization)
        let leaf = try r.stem.spawnLeaf(raw: "#localize(\"en\", \"welcome\", \"title\")")
        let rendered = try r.stem.render(leaf, with: LeafContext(Node.null)).string
        XCTAssert(rendered == "Welcome to Vapor!")
    }


    func testViewResponse() throws {
        let view = try View(bytes: "42 🚀".bytes)
        let response = view.makeResponse()

        XCTAssertEqual(response.headers["content-type"], "text/html; charset=utf-8")
        XCTAssertEqual(try response.bodyString(), "42 🚀")
    }
}
