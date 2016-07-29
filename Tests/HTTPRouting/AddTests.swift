import XCTest
import HTTP
import HTTPRouting

class AddTests: XCTestCase {
    static var allTests = [
        ("testBasic", testBasic),
        ("testVariadic", testVariadic)
    ]

    func testBasic() throws {
        let router = Router()
        router.add(.get, "ferret") { request in
            return "foo"
        }

        let request = Request(method: .get, path: "ferret")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "foo".bytes)
    }

    func testVariadic() throws {
        let router = Router()
        router.add(.trace, "foo", "bar", "baz") { request in
            return "1337"
        }

        let request = Request(method: .trace, path: "foo/bar/baz")
        let bytes = try request.bytes(running: router)
        
        XCTAssertEqual(bytes, "1337".bytes)
    }
}
