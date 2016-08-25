import XCTest
@testable import Cookies

class ParsingTests: XCTestCase {
    static let allTests = [
        ("testBytes", testBytes),
        ("testDomain", testDomain),
        ("testPath", testPath),
        ("testExpires", testExpires),
        ("testHTTPOnly", testHTTPOnly),
        ("testSecure", testSecure),
        ("testMaxAge", testMaxAge),
        ("testMaxAgeInvalid", testMaxAgeInvalid),
        ("testInvalid", testInvalid),
        ("testMultiple", testMultiple)
    ]

    func testBytes() throws {
        let cookie = try Cookie(bytes: "hi=42".bytes)
        XCTAssertEqual(cookie.name, "hi")
        XCTAssertEqual(cookie.value, "42")
    }

    func testDomain() throws {
        let cookie = try Cookie("cookie=1337; Domain=vapor.codes")
        XCTAssertEqual(cookie.domain, "vapor.codes")
    }

    func testPath() throws {
        let cookie = try Cookie("cookie=1337; Path=/path/to/foo")
        XCTAssertEqual(cookie.path, "/path/to/foo")
    }

    func testExpires() throws {
        let cookie = try Cookie("cookie=1337; Expires=Wed, 13 Jan 2021 22:23:01 GMT;")
        XCTAssertEqual(cookie.expires?.rfc1123, "Wed, 13 Jan 2021 22:23:01 GMT")
    }

    func testHTTPOnly() throws {
        let cookie = try Cookie("cookie=1337; HttpOnly")
        XCTAssertEqual(cookie.httpOnly, true)
    }

    func testSecure() throws {
        let cookie = try Cookie("cookie=1337; Secure")
        XCTAssertEqual(cookie.secure, true)
    }

    func testMaxAge() throws {
        let cookie = try Cookie("cookie=1337; Max-Age=5")
        XCTAssertEqual(cookie.maxAge, 5)
    }

    func testMaxAgeInvalid() throws {
        let cookie = try Cookie("cookie=1337; Max-Age=asdf")
        XCTAssertEqual(cookie.maxAge, 0)
    }

    func testInvalid() throws {
        do {
            _ = try Cookie("secure")
            XCTFail("Should have failed.")
        } catch Cookie.Error.invalidBytes {
            //
        } catch {
            XCTFail("Invalid error: \(error)")
        }
    }

    func testMultiple() throws {
        let cookies = try Cookies(bytes: "life=42;leet=1337".bytes)
        XCTAssertEqual(cookies.cookies.count, 2)
        let result = try cookies.makeBytes().string
        XCTAssert(result.contains("life=42"))
        XCTAssert(result.contains("leet=1337"))
    }
}
