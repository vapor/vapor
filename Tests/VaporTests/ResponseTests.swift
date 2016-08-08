import XCTest
@testable import Vapor

class ResponseTests: XCTestCase {
    static let allTests = [
       ("testCookiesSerialization", testCookiesSerialization)
    ]

    func testCookiesSerialization() {
        var cookies: Cookies = []
        cookies["key"] = "val"

        let data = cookies.serialize()

        let expected = "key=val"
        XCTAssert(data == expected, "Cookies did not serialize")
    }
}
