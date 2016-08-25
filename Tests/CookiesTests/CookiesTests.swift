import XCTest
@testable import Cookies

class CookiesTests: XCTestCase {
    static let allTests = [
        ("testInit", testInit),
        ("testRemove", testRemove),
    ]

    func testInit() throws {
        let cookie = Cookie(name: "life", value: "42")
        let cookies = Cookies(cookies: [cookie])
        XCTAssertEqual(cookies.cookies.count, 1)
    }

    func testRemove() throws {
        let cookie = Cookie(name: "life", value: "42")
        var cookies = Cookies()

        cookies.insert(cookie)
        XCTAssertEqual(cookies.cookies.count, 1)
        cookies.insert(cookie)
        XCTAssertEqual(cookies.cookies.count, 1)
        cookies.remove(cookie)

        XCTAssertEqual(cookies.cookies.count, 0)
        cookies.insert(cookie)
        XCTAssertEqual(cookies.cookies.count, 1)
        XCTAssert(cookies.contains(cookie))
        cookies.removeAll()
        XCTAssertEqual(cookies.cookies.count, 0)

        cookies.insert(cookie)
        XCTAssertEqual(cookies.cookies.count, 1)
        cookies["life"] = nil
        XCTAssertEqual(cookies.cookies.count, 0)
    }
}
