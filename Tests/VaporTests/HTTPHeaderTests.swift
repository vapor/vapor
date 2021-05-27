@testable import Vapor
import XCTest

final class HTTPHeaderTests: XCTestCase {
    func testValue() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "foobar")
        XCTAssertEqual(parser.nextDirectives(), [.init(value: "foobar")])
    }

    func testValue_whitespace() throws {
        var parser = HTTPHeaders.DirectiveParser(string: " foobar  ")
        XCTAssertEqual(parser.nextDirectives(), [.init(value: "foobar")])
    }

    func testValue_semicolon_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""foo;bar""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo;bar")
        ])
    }

    func testValue_semicolon_quote_escape() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""foo;\"bar""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: #"foo;"bar"#)
        ])
    }

    func testValue_directives() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"a; b=c, d"#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "a"),
            .init(value: "b", parameter: "c"),
        ])
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "d")
        ])
    }

    func testValue_directives_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""a;b"; c="d;e", f"#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "a;b"),
            .init(value: "c", parameter: "d;e"),
        ])
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "f")
        ])
    }

    func testValue_directives_contentType() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "application/json; charset=utf8")
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "application/json"),
            .init(value: "charset", parameter: "utf8"),
        ])
    }

    func testValue_directives_multiple() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "foo; bar=1; baz=2")
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    func testValue_directives_multiple_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    func testValue_directives_multiple_quotedSemicolon() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2;3""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;3"),
        ])
    }

    func testValue_directives_multiple_quotedSemicolonEqual() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2;=3""#)
        XCTAssertEqual(parser.nextDirectives(), [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;=3"),
        ])
    }

    func testValue_serialize() throws {
        let serializer = HTTPHeaders.DirectiveSerializer.init(directives: [
            [.init(value: "foo"), .init(value: "bar", parameter: "baz")],
            [.init(value: "qux", parameter: "quuz")]
        ])
        XCTAssertEqual(serializer.serialize(), "foo; bar=baz, qux=quuz")
    }

    func testForwarded() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: "for=192.0.2.60;proto=http;by=203.0.113.43")
        XCTAssertEqual(headers.forwarded.first?.for, "192.0.2.60")
        XCTAssertEqual(headers.forwarded.first?.proto, "http")
        XCTAssertEqual(headers.forwarded.first?.by, "203.0.113.43")
    }

    func testAcceptType() throws {
        var headers = HTTPHeaders()

        // Simple accept type
        do {
            headers.replaceOrAdd(name: .accept, value: "text/html")
            XCTAssertEqual(headers.accept.mediaTypes.count, 1)
            XCTAssertTrue(headers.accept.mediaTypes.contains(.html))
        }

        // Complex accept type (used e.g. from safari browser)
        do {
            headers.replaceOrAdd(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9,image/png;q=0.8")
            XCTAssertEqual(headers.accept.mediaTypes.count, 4)
            XCTAssertTrue(headers.accept.mediaTypes.contains(.html))
            XCTAssertTrue(headers.accept.mediaTypes.contains(.xml))
            XCTAssertTrue(headers.accept.mediaTypes.contains(.png))
            XCTAssertTrue(headers.accept.comparePreference(for: .html, to: .xml) == .orderedDescending)
            XCTAssertEqual(headers.accept.first(where: { $0.mediaType == .xml })?.q, 0.9)
            XCTAssertEqual(headers.accept.first(where: { $0.mediaType == .png })?.q, 0.8)
            XCTAssertTrue(headers.accept.comparePreference(for: .xml, to: .png) == .orderedDescending)
        }
    }

    func testComplexCookieParsing() throws {
        var headers = HTTPHeaders()
        do {
            headers.add(name: .setCookie, value: "SIWA_STATE=CJKxa71djx6CaZ0MwRjtvtJ5Zub+kfaoIEZGoY3wXKA=; Path=/; SameSite=None; HttpOnly; Secure")
            headers.add(name: .setCookie, value: "vapor-session=TL7r+TS3RNhpEC6HoCfukq+7edNHKF2elF6WiKV4JCg=; Expires=Wed, 02 Jun 2021 14:57:57 GMT; Path=/; SameSite=None; HttpOnly; Secure")
            XCTAssertEqual(headers.setCookie?.all.count, 2)
            let siwaState = try XCTUnwrap(headers.setCookie?["SIWA_STATE"])
            XCTAssertEqual(siwaState.sameSite, HTTPCookies.SameSitePolicy.none)
            XCTAssertEqual(siwaState.expires, nil)
            XCTAssertTrue(siwaState.isHTTPOnly)
            XCTAssertTrue(siwaState.isSecure)

            let vaporSession = try XCTUnwrap(headers.setCookie?["vapor-session"])
            XCTAssertEqual(vaporSession.sameSite, HTTPCookies.SameSitePolicy.none)
            XCTAssertEqual(vaporSession.expires, Date(timeIntervalSince1970: 1622645877))
            XCTAssertTrue(siwaState.isHTTPOnly)
            XCTAssertTrue(siwaState.isSecure)
        }
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

    func testCookie_parsing() throws {
        let headers = HTTPHeaders([
            (
                "cookie",
                """
                vapor-session=0FuTYcHmGw7Bz1G4HiF+EA==; _ga=GA1.1.500315824.1585154561; _gid=GA1.1.500224287.1585154561; !#$%&'*+-.^_`~=symbols
                """
            )
        ])
        print(headers.cookie!.all.keys)
        XCTAssertEqual(headers.cookie?["vapor-session"]?.string, "0FuTYcHmGw7Bz1G4HiF+EA==")
        XCTAssertEqual(headers.cookie?["vapor-session"]?.sameSite, .lax)
        XCTAssertEqual(headers.cookie?["_ga"]?.string, "GA1.1.500315824.1585154561")
        XCTAssertEqual(headers.cookie?["_gid"]?.string, "GA1.1.500224287.1585154561")
        XCTAssertEqual(headers.cookie?["!#$%&'*+-.^_`~"]?.string, "symbols")
    }

    // https://github.com/vapor/vapor/issues/2316
    func testCookie_complexParsing() throws {
        let headers = HTTPHeaders([
            ("cookie", "oauth2_authentication_csrf=MTU4NzA1MTc0N3xEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJRGs1WkRKbU1HRTVNMlF3TmpRM1lUbGhOelptTnprMU5EYzRZMlk1WkRObXx6lRdSC3-hPvE1pxp4ylFlBruOyJtRo8OnzBrAriBr0w==; vapor-session=ZFPQ46p3frNX52i3dM+JFlWbTxQX5rtGuQ5r7Gb6JUs=; oauth2_consent_csrf=MTU4NjkzNzgwMnxEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJR1ExWVRnM09USmhOamRsWXpSbU4yRmhOR1UwTW1KaU5tRXpPRGczTmpjMHweHbVecAf193ev3_1Tcf60iY9jSsq5-IQxGTyoztRTfg==")
        ])

        XCTAssertEqual(headers.cookie?["oauth2_authentication_csrf"]?.string, "MTU4NzA1MTc0N3xEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJRGs1WkRKbU1HRTVNMlF3TmpRM1lUbGhOelptTnprMU5EYzRZMlk1WkRObXx6lRdSC3-hPvE1pxp4ylFlBruOyJtRo8OnzBrAriBr0w==")
        XCTAssertEqual(headers.cookie?["vapor-session"]?.string, "ZFPQ46p3frNX52i3dM+JFlWbTxQX5rtGuQ5r7Gb6JUs=")
        XCTAssertEqual(headers.cookie?["oauth2_consent_csrf"]?.string, "MTU4NjkzNzgwMnxEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJR1ExWVRnM09USmhOamRsWXpSbU4yRmhOR1UwTW1KaU5tRXpPRGczTmpjMHweHbVecAf193ev3_1Tcf60iY9jSsq5-IQxGTyoztRTfg==")
    }
    
    func testCookie_invalidCookie() throws {
        let headers = HTTPHeaders([
            ("cookie", "cookie_one=1;cookie\ntwo=2;cookie_three=3;cookie_④=4;cookie_fivé=5")
        ])
        
        XCTAssertEqual(headers.cookie?.all.count, 2)
        XCTAssertEqual(headers.cookie?["cookie_one"]?.string, "1")
        XCTAssertNil(headers.cookie?["cookie\ntwo"])
        XCTAssertEqual(headers.cookie?["cookie_three"]?.string, "3")
        XCTAssertNil(headers.cookie?["cookie_④"])
        XCTAssertNil(headers.cookie?["cookie_fivé"])
    }

    func testMediaTypeMainTypeCaseInsensitive() throws {
        let lower = HTTPMediaType(type: "foo", subType: "")
        let upper = HTTPMediaType(type: "FOO", subType: "")
        XCTAssertEqual(lower, upper)
    }

    func testMediaTypeSubTypeCaseInsensitive() throws {
        let lower = HTTPMediaType(type: "foo", subType: "bar")
        let upper = HTTPMediaType(type: "foo", subType: "BAR")
        XCTAssertEqual(lower, upper)
    }

    // https://github.com/vapor/vapor/issues/2439
    func testContentDispositionQuotedFilename() throws {
        var headers = HTTPHeaders()
        headers.contentDisposition = .init(.formData, filename: "foo")
        XCTAssertEqual(headers.first(name: .contentDisposition), "form-data; filename=foo")
        headers.contentDisposition = .init(.formData, filename: "foo bar")
        XCTAssertEqual(headers.first(name: .contentDisposition), #"form-data; filename="foo bar""#)
        headers.contentDisposition = .init(.formData, filename: "foo\"bar")
        XCTAssertEqual(headers.first(name: .contentDisposition), #"form-data; filename="foo\"bar""#)
    }
      
    func testRangeDirectiveSerialization() throws {
        let range = HTTPHeaders.Range(unit: .bytes, ranges: [
            .within(start: 200, end: 1000),
            .within(start: 2000, end: 6576),
            .start(value: 19000),
            .tail(value: 500)
        ])
        var headers = HTTPHeaders()
        headers.range = range
        XCTAssertEqual(range, headers.range)
    }
    
    func testContentRangeDirectiveSerialization() throws {
        let anyRange = HTTPHeaders.ContentRange(
            unit: .bytes,
            range: .any(size: 1000)
        )
        let rangeOfUnknownLimit = HTTPHeaders.ContentRange(
            unit: .bytes,
            range: .within(start: 0, end: 1000)
        )
        let rangeWithLimit = HTTPHeaders.ContentRange(
            unit: .bytes,
            range: .withinWithLimit(start: 0, end: 1000, limit: 1001)
        )
        var headers = HTTPHeaders()
        headers.contentRange = anyRange
        XCTAssertEqual(headers.contentRange, anyRange)
        headers.contentRange = rangeOfUnknownLimit
        XCTAssertEqual(headers.contentRange, rangeOfUnknownLimit)
        headers.contentRange = rangeWithLimit
        XCTAssertEqual(headers.contentRange, rangeWithLimit)
    }
    
    func testRangeSerialization() throws {
        let range = HTTPHeaders.Range(unit: .bytes, ranges: [
            .within(start: 200, end: 1000),
            .within(start: 2000, end: 6576),
            .start(value: 19000),
            .tail(value: 500)
        ])
        XCTAssertEqual(range.serialize(), "bytes=200-1000, 2000-6576, 19000-, -500")
    }
    
    func testRangeDeserialization() throws {
        let range = HTTPHeaders.Range(unit: .bytes, ranges: [
            .within(start: 200, end: 1000),
            .within(start: 2000, end: 6576),
            .start(value: 19000),
            .tail(value: 500)
        ])
        let directives = [HTTPHeaders.Directive(value: "bytes", parameter: "200-1000"),
                          HTTPHeaders.Directive(value: "2000-6576"),
                          HTTPHeaders.Directive(value: "19000-"),
                          HTTPHeaders.Directive(value: "-500"),]
        XCTAssertEqual(HTTPHeaders.Range(directives: directives), range)
    }
    
    func testContentRangeSerialization() throws {
        let anyRange = HTTPHeaders.ContentRange(unit: .bytes, range: .any(size: 1000))
        let rangeOfUnknownLimit = HTTPHeaders.ContentRange(unit: .bytes, range: .within(start: 0, end: 1000))
        let rangeWithLimit = HTTPHeaders.ContentRange(
            unit: .bytes,
            range: .withinWithLimit(start: 0, end: 1000, limit: 1001)
        )
        XCTAssertEqual(anyRange.serialize(), "bytes */1000")
        XCTAssertEqual(rangeOfUnknownLimit.serialize(), "bytes 0-1000/*")
        XCTAssertEqual(rangeWithLimit.serialize(), "bytes 0-1000/1001")
    }
    
    func testContentRangeDeserialization() throws {
        XCTAssertEqual(
            HTTPHeaders.ContentRange(directive: HTTPHeaders.Directive(value: "bytes */1000")),
            HTTPHeaders.ContentRange(unit: .bytes, range: .any(size: 1000))
        )
        XCTAssertEqual(
            HTTPHeaders.ContentRange(directive: HTTPHeaders.Directive(value: "bytes 0-1000/*")),
            HTTPHeaders.ContentRange(unit: .bytes, range: .within(start: 0, end: 1000))
        )
        XCTAssertEqual(
            HTTPHeaders.ContentRange(directive: HTTPHeaders.Directive(value: "bytes 0-1000/1001")),
            HTTPHeaders.ContentRange(unit: .bytes, range: .withinWithLimit(start: 0, end: 1000, limit: 1001))
        )
    }
}
