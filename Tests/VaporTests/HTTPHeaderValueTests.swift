@testable import Vapor
import XCTest

final class HTTPHeaderValueTests: XCTestCase {
    func testValue() throws {
        var parser = HTTPHeaders.ValueParser(string: "foobar")
        XCTAssertEqual(parser.nextDirectives(), [.init(value: "foobar")])
    }

    func testValue_whitespace() throws {
        var parser = HTTPHeaders.ValueParser(string: " foobar  ")
        XCTAssertEqual(parser.nextDirectives(), [.init(value: "foobar")])
    }

    func testValue_semicolon_quote() throws {
        var parser = HTTPHeaders.ValueParser(string: #""foo;bar""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo;bar")
        ])
    }

    func testValue_semicolon_quote_escape() throws {
        var parser = HTTPHeaders.ValueParser(string: #""foo;\"bar""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: #"foo;"bar"#)
        ])
    }

    func testValue_directives() throws {
        var parser = HTTPHeaders.ValueParser(string: #"a; b=c, d"#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "a"),
            .init(value: "b", parameter: "c"),
        ])
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "d")
        ])
    }

    func testValue_directives_quote() throws {
        var parser = HTTPHeaders.ValueParser(string: #""a;b"; c="d;e", f"#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "a;b"),
            .init(value: "c", parameter: "d;e"),
        ])
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "f")
        ])
    }

    func testValue_directives_contentType() throws {
        var parser = HTTPHeaders.ValueParser(string: "application/json; charset=utf8")
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "application/json"),
            .init(value: "charset", parameter: "utf8"),
        ])
    }

    func testValue_directives_multiple() throws {
        var parser = HTTPHeaders.ValueParser(string: "foo; bar=1; baz=2")
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    func testValue_directives_multiple_quote() throws {
        var parser = HTTPHeaders.ValueParser(string: #"foo; bar=1; baz="2""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    func testValue_directives_multiple_quotedSemicolon() throws {
        var parser = HTTPHeaders.ValueParser(string: #"foo; bar=1; baz="2;3""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;3"),
        ])
    }

    func testValue_directives_multiple_quotedSemicolonEqual() throws {
        var parser = HTTPHeaders.ValueParser(string: #"foo; bar=1; baz="2;=3""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;=3"),
        ])
    }

    func testForwarded() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: "for=192.0.2.60;proto=http;by=203.0.113.43")
        XCTAssertEqual(headers.forwarded.first?.for, "192.0.2.60")
        XCTAssertEqual(headers.forwarded.first?.proto, "http")
        XCTAssertEqual(headers.forwarded.first?.by, "203.0.113.43")
    }

    func testForwarded_quote() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"For="[2001:db8:cafe::17]:4711""#)
        XCTAssertEqual(headers.forwarded.first?.for, "[2001:db8:cafe::17]:4711")
    }

    func testForwarded_multiple() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"for=192.0.2.43, for="[2001:db8:cafe::17]""#)
        XCTAssertEqual(headers.forwarded.map { $0.for }, [
            "192.0.2.43",
            "[2001:db8:cafe::17]",
        ])
    }

    func testForwarded_multiple_deprecated() throws {
        let headers = HTTPHeaders([
            ("X-Forwarded-For", "192.0.2.43, 2001:db8:cafe::17 ")
        ])
        XCTAssertEqual(headers.forwarded.map { $0.for }, [
            "192.0.2.43",
            "2001:db8:cafe::17",
        ])
    }

    func testForwarded_serialization() throws {
        var headers = HTTPHeaders()
        headers.forwarded.append(.init(
            by: "203.0.113.43",
            for: "192.0.2.60",
            host: nil,
            proto: "http"
        ))
        XCTAssertEqual(
            headers.first(name: "Forwarded"),
            "by=203.0.113.43; for=192.0.2.60; proto=http"
        )
    }

    func testContentDisposition() throws {
        let headers = HTTPHeaders([
            ("Content-Disposition", #"form-data; name="fieldName"; filename="filename.jpg""#)
        ])
        XCTAssertEqual(headers.contentDisposition?.value, .formData)
        XCTAssertEqual(headers.contentDisposition?.name, "fieldName")
        XCTAssertEqual(headers.contentDisposition?.filename, "filename.jpg")
    }
}
