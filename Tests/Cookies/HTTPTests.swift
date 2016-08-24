import XCTest
@testable import Cookies
import HTTP
import URI

class HTTPTests: XCTestCase {
    static let allTests = [
        ("testRequestParse", testRequestParse),
    ]

    func testRequestParse() throws {
        let request = Request()
        request.headers["Cookie"] = "life=42;leet=1337"
        XCTAssertEqual(request.cookies.cookies.count, 2)
        XCTAssertEqual(request.cookies.cookies.count, 2)
    }

    func testRequestParseFail() throws {
        let request = Request()
        request.headers["Cookie"] = "Path=/"
        XCTAssertEqual(request.cookies.cookies.count, 0)
    }

    func testRequestParseNothing() throws {
        let request = Request()
        XCTAssertEqual(request.cookies.cookies.count, 0)
    }

    func testRequestSerialize() throws {
        let cookies = try Cookies("life=42;leet=1337".bytes, for: .request)
        let request = Request()
        request.cookies = cookies
        XCTAssertEqual(request.headers["cookie"], "leet=1337; life=42")
    }

    func testResponseParse() throws {
        let response = Response()
        response.headers["Set-Cookie"] = "life=42\r\nSet-Cookie: leet=1337"
        XCTAssertEqual(response.cookies.cookies.count, 2)
        XCTAssertEqual(response.cookies.cookies.count, 2)
    }

    func testResponseParseFail() throws {
        let response = Response()
        response.headers["Set-Cookie"] = "life=42\r\nSet-Cookie: Path=/"
        XCTAssertEqual(response.cookies.cookies.count, 0)
    }


    func testResponseParseNothing() throws {
        let response = Response()
        XCTAssertEqual(response.cookies.cookies.count, 0)
    }
}
