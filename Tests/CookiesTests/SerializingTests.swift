import XCTest
@testable import Cookies

class SerializingTests: XCTestCase {
    static let allTests = [
        ("testRequest", testRequest),
        ("testResponse", testResponse),
        ("testEmpty", testEmpty),
    ]

    func testRequest() throws {
        var cookies = Cookies()

        cookies["life"] = "42"
        cookies["leet"] = "1337"

        let serialized = cookies.serialize(for: .request)
        XCTAssert(serialized.contains("leet=1337"))
        XCTAssert(serialized.contains("life=42"))
    }

    func testResponse() throws {
        var cookies = Cookies()

        cookies["life"] = "42"
        cookies["leet"] = "1337"

        let serialized = cookies.serialize(for: .response)

        XCTAssert(serialized.contains("leet=1337; Path=/"))
        XCTAssert(serialized.contains("life=42; Path=/"))
    }

    func testEmpty() throws {
        let cookies = Cookies()
        let serialized = cookies.serialize(for: .response)
        XCTAssertEqual(serialized, "")
    }
}
