import XCTest
@testable import Vapor

class ResponseTests: XCTestCase {
    static let allTests = [
       ("testRedirect", testRedirect),
       ("testCookiesSerialization", testCookiesSerialization)
    ]

    func testRedirect() {
        let url = "http://tanner.xyz"

        let redirect = Response(redirect: url)
        XCTAssert(redirect.headers["location"] == url, "Location header should be in headers")
    }

    func testCookiesSerialization() {
        var cookies: Cookies = []
        cookies["key"] = "val"

        let data = cookies.serialize()

        let expected = "key=val"
        XCTAssert(data == expected.data, "Cookies did not serialize")
    }
}
