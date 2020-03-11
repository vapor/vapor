@testable import Vapor
import XCTest

final class HTTPHeaderValueTests: XCTestCase {
    func testValue() throws {
        var parser = HTTPHeaderValueParser(string: "foobar")
        XCTAssertEqual(parser.nextValue(), "foobar")
    }
    func testValue_whitespace() throws {
        var parser = HTTPHeaderValueParser(string: " foobar  ")
        XCTAssertEqual(parser.nextValue(), "foobar")
    }

    func testValue_semicolon_quote() throws {
        var parser = HTTPHeaderValueParser(string: #""foo;bar""#)
        XCTAssertEqual(parser.nextValue(), "foo;bar")
    }

    func testValue_semicolon_quote_escape() throws {
        var parser = HTTPHeaderValueParser(string: #""foo;\"bar""#)
        XCTAssertEqual(parser.nextValue(), #"foo;"bar"#)
    }

    func testParameter() throws {
        var parser = HTTPHeaderValueParser(string: "application/json; charset=utf8")
        XCTAssertEqual(parser.nextValue(), "application/json")
        let charset = parser.nextParameter()
        XCTAssertEqual(charset?.key, "charset")
        XCTAssertEqual(charset?.value, "utf8")
    }

    func testParameter_multiple() throws {
        var parser = HTTPHeaderValueParser(string: "foo; bar=1; baz=2")
        XCTAssertEqual(parser.nextValue(), "foo")
        let bar = parser.nextParameter()
        XCTAssertEqual(bar?.key, "bar")
        XCTAssertEqual(bar?.value, "1")
        let baz = parser.nextParameter()
        XCTAssertEqual(baz?.key, "baz")
        XCTAssertEqual(baz?.value, "2")
    }

    func testParameter_multiple_quote() throws {
        var parser = HTTPHeaderValueParser(string: #"foo; bar=1; baz="2""#)
        XCTAssertEqual(parser.nextValue(), "foo")
        let bar = parser.nextParameter()
        XCTAssertEqual(bar?.key, "bar")
        XCTAssertEqual(bar?.value, "1")
        let baz = parser.nextParameter()
        XCTAssertEqual(baz?.key, "baz")
        XCTAssertEqual(baz?.value, "2")
    }

    func testParameter_multiple_semicolon_quote() throws {
        var parser = HTTPHeaderValueParser(string: #"foo; bar=1; baz="2;3""#)
        XCTAssertEqual(parser.nextValue(), "foo")
        let bar = parser.nextParameter()
        XCTAssertEqual(bar?.key, "bar")
        XCTAssertEqual(bar?.value, "1")
        let baz = parser.nextParameter()
        XCTAssertEqual(baz?.key, "baz")
        XCTAssertEqual(baz?.value, "2;3")
    }

    func testParameter_multiple_semicolon_equal_quote() throws {
        var parser = HTTPHeaderValueParser(string: #"foo; bar=1; baz="2;=3""#)
        XCTAssertEqual(parser.nextValue(), "foo")
        let bar = parser.nextParameter()
        XCTAssertEqual(bar?.key, "bar")
        XCTAssertEqual(bar?.value, "1")
        let baz = parser.nextParameter()
        XCTAssertEqual(baz?.key, "baz")
        XCTAssertEqual(baz?.value, "2;=3")
    }

    func testForwarded() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: "for=192.0.2.60;proto=http;by=203.0.113.43")
        XCTAssertEqual(headers.forwarded?.for, ["192.0.2.60"])
        XCTAssertEqual(headers.forwarded?.proto, ["http"])
        XCTAssertEqual(headers.forwarded?.by, ["203.0.113.43"])
    }

    func testForwarded_quote() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"For="[2001:db8:cafe::17]:4711""#)
        XCTAssertEqual(headers.forwarded?.for, ["[2001:db8:cafe::17]:4711"])
    }

    func testForwarded_multiple() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"for=192.0.2.43, for="[2001:db8:cafe::17]""#)
        XCTAssertEqual(headers.forwarded?.for, [
            "192.0.2.43",
            "[2001:db8:cafe::17]",
        ])
    }

    func testForwardedFor_multiple() throws {
        let headers = HTTPHeaders([
            ("X-Forwarded-For", "192.0.2.43, 2001:db8:cafe::17 ")
        ])
        XCTAssertEqual(headers.forwarded?.for, [
            "192.0.2.43",
            "2001:db8:cafe::17",
        ])
    }
}
