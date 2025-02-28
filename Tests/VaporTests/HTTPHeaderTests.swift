@testable import Vapor
import NIOHTTP1
import Testing
import Foundation

@Suite("HTTP Header Tests")
struct HTTPHeaderTests {
    @Test("Test Value Parsing")
    func testValue() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "foobar")
        #expect(parser.nextDirectives() == [.init(value: "foobar")])
    }

    @Test("Test Value Parsing with Whitespace")
    func testValue_whitespace() throws {
        var parser = HTTPHeaders.DirectiveParser(string: " foobar  ")
        #expect(parser.nextDirectives() == [.init(value: "foobar")])
    }

    @Test("Test Value Parsing with Semicolon in Quotes")
    func testValue_semicolon_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""foo;bar""#)
        #expect(parser.nextDirectives() == [.init(value: "foo;bar")])
    }

    @Test("Test Value Parsing with Semicolon and Escaped Quotes")
    func testValue_semicolon_quote_escape() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""foo;\"bar""#)
        #expect(parser.nextDirectives() == [.init(value: #"foo;"bar"#)])
    }

    @Test("Test Directive Parsing with Parameters")
    func testValue_directives() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"a; b=c, d"#)
        #expect(parser.nextDirectives() == [
            .init(value: "a"),
            .init(value: "b", parameter: "c"),
        ])
        #expect(parser.nextDirectives() == [
            .init(value: "d")
        ])
    }

    @Test("Test Directive Parsing with Quoted Parameters")
    func testValue_directives_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #""a;b"; c="d;e", f"#)
        #expect(parser.nextDirectives() == [
            .init(value: "a;b"),
            .init(value: "c", parameter: "d;e"),
        ])
        #expect(parser.nextDirectives() == [
            .init(value: "f")
        ])
    }

    @Test("Test Directive Parsing for Content-Type")
    func testValue_directives_contentType() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "application/json; charset=utf8")
        #expect(parser.nextDirectives() == [
            .init(value: "application/json"),
            .init(value: "charset", parameter: "utf8"),
        ])
    }

    @Test("Test Multiple Directives Parsing")
    func testValue_directives_multiple() throws {
        var parser = HTTPHeaders.DirectiveParser(string: "foo; bar=1; baz=2")
        #expect(parser.nextDirectives() == [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    @Test("Test Multiple Directives Parsing with Quotes")
    func testValue_directives_multiple_quote() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2""#)
        #expect(parser.nextDirectives() == [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2"),
        ])
    }

    @Test("Test Multiple Directives Parsing with Quoted Semicolon")
    func testValue_directives_multiple_quotedSemicolon() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2;3""#)
        #expect(parser.nextDirectives() == [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;3"),
        ])
    }

    @Test("Test Multiple Directives Parsing with Quoted Semicolon and Equals")
    func testValue_directives_multiple_quotedSemicolonEqual() throws {
        var parser = HTTPHeaders.DirectiveParser(string: #"foo; bar=1; baz="2;=3""#)
        #expect(parser.nextDirectives() == [
            .init(value: "foo"),
            .init(value: "bar", parameter: "1"),
            .init(value: "baz", parameter: "2;=3"),
        ])
    }

    @Test("Test Directive Serialization")
    func testValue_serialize() throws {
        let serializer = HTTPHeaders.DirectiveSerializer(directives: [
            [.init(value: "foo"), .init(value: "bar", parameter: "baz")],
            [.init(value: "qux", parameter: "quuz")]
        ])
        #expect(serializer.serialize() == "foo; bar=\"baz\", qux=\"quuz\"")
    }

    @Test("Test Forwarded Header Parsing")
    func testForwarded() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: "for=192.0.2.60;proto=http;by=203.0.113.43")

        #expect(headers.forwarded.first?.for == "192.0.2.60")
        #expect(headers.forwarded.first?.proto == "http")
        #expect(headers.forwarded.first?.by == "203.0.113.43")
    }

    @Test("Test Accept Header Parsing")
    func testAcceptType() throws {
        var headers = HTTPHeaders()

        // Simple accept type
        do {
            headers.replaceOrAdd(name: .accept, value: "text/html")
            #expect(headers.accept.mediaTypes.count == 1)
            #expect(headers.accept.mediaTypes.contains(.html))
        }

        // Complex accept type (used e.g. from Safari browser)
        do {
            headers.replaceOrAdd(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9,image/png;q=0.8")
            #expect(headers.accept.mediaTypes.count == 4)
            #expect(headers.accept.mediaTypes.contains(.html))
            #expect(headers.accept.mediaTypes.contains(.xml))
            #expect(headers.accept.mediaTypes.contains(.png))
            #expect(headers.accept.comparePreference(for: .html, to: .xml) == .orderedDescending)
            #expect(headers.accept.first(where: { $0.mediaType == .xml })?.q == 0.9)
            #expect(headers.accept.first(where: { $0.mediaType == .png })?.q == 0.8)
            #expect(headers.accept.comparePreference(for: .xml, to: .png) == .orderedDescending)
        }

        // #2668 Preference should be consistent: present types are preferred to missing types
        do {
            headers.replaceOrAdd(name: .accept, value: "image/png;q=0.5")
            #expect(headers.accept.comparePreference(for: .png, to: .gif) == .orderedDescending)
            #expect(headers.accept.comparePreference(for: .gif, to: .png) == .orderedAscending)
            #expect(headers.accept.comparePreference(for: .png, to: .png) == .orderedSame)
            #expect(headers.accept.comparePreference(for: .gif, to: .gif) == .orderedSame)
        }
    }

    @Test("Test Complex Cookie Parsing")
    func testComplexCookieParsing() throws {
        var headers = HTTPHeaders()
        do {
            headers.add(name: .setCookie, value: "SIWA_STATE=CJKxa71djx6CaZ0MwRjtvtJ5Zub+kfaoIEZGoY3wXKA=; Path=/; SameSite=None; HttpOnly; Secure")
            headers.add(name: .setCookie, value: "vapor-session=TL7r+TS3RNhpEC6HoCfukq+7edNHKF2elF6WiKV4JCg=; Expires=Wed, 02 Jun 2021 14:57:57 GMT; Path=/; SameSite=None; HttpOnly; Secure")

            #expect(headers.setCookie?.all.count == 2)

            let siwaState = try #require(headers.setCookie?["SIWA_STATE"])
            #expect(siwaState.sameSite == HTTPCookies.SameSitePolicy.none)
            #expect(siwaState.expires == nil)
            #expect(siwaState.isHTTPOnly)
            #expect(siwaState.isSecure)

            let vaporSession = try #require(headers.setCookie?["vapor-session"])
            #expect(vaporSession.sameSite == HTTPCookies.SameSitePolicy.none)
            #expect(vaporSession.expires == Date(timeIntervalSince1970: 1622645877))
            #expect(vaporSession.isHTTPOnly)
            #expect(vaporSession.isSecure)
        }
    }

    @Test("Test Forwarded Header with Quoted Value")
    func testForwarded_quote() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"For="[2001:db8:cafe::17]:4711""#)

        #expect(headers.forwarded.first?.for == "[2001:db8:cafe::17]:4711")
    }

    @Test("Test Multiple Forwarded Headers")
    func testForwarded_multiple() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .forwarded, value: #"for=192.0.2.43, for="[2001:db8:cafe::17]""#)

        #expect(headers.forwarded.map { $0.for } == [
            "192.0.2.43",
            "[2001:db8:cafe::17]",
        ])
    }

    @Test("Test Multiple Forwarded Headers (Deprecated)")
    func testForwarded_multiple_deprecated() throws {
        let headers = HTTPHeaders([
            ("X-Forwarded-For", "192.0.2.43, 2001:db8:cafe::17 ")
        ])

        #expect(headers.forwarded.map { $0.for } == [
            "192.0.2.43",
            "2001:db8:cafe::17",
        ])
    }

    @Test("Test Forwarded Header Serialization")
    func testForwarded_serialization() throws {
        var headers = HTTPHeaders()
        headers.forwarded.append(.init(
            by: "203.0.113.43",
            for: "192.0.2.60",
            host: nil,
            proto: "http"
        ))

        #expect(headers.first(name: "Forwarded") ==
            #"by="203.0.113.43"; for="192.0.2.60"; proto="http""#)
    }

    @Test("Test X-Request-Id Header")
    func testXRequestId() throws {
        var headers = HTTPHeaders()
        let xRequestId = UUID().uuidString
        headers.replaceOrAdd(name: .xRequestId, value: xRequestId)

        #expect(headers.first(name: "X-Request-Id") == xRequestId)
    }

    @Test("Test Content-Disposition Header Parsing")
    func testContentDisposition() throws {
        let headers = HTTPHeaders([
            ("Content-Disposition", #"form-data; name="fieldName"; filename="filename.jpg""#)
        ])

        #expect(headers.contentDisposition?.value == .formData)
        #expect(headers.contentDisposition?.name == "fieldName")
        #expect(headers.contentDisposition?.filename == "filename.jpg")
    }

    @Test("Test Cookie Parsing")
    func testCookie_parsing() throws {
        let headers = HTTPHeaders([
            (
                "cookie",
                """
                vapor-session=0FuTYcHmGw7Bz1G4HiF+EA==; _ga=GA1.1.500315824.1585154561; _gid=GA1.1.500224287.1585154561; !#$%&'*+-.^_`~=symbols
                """
            )
        ])

        #expect(headers.cookie?["vapor-session"]?.string == "0FuTYcHmGw7Bz1G4HiF+EA==")
        #expect(headers.cookie?["vapor-session"]?.sameSite == .lax)
        #expect(headers.cookie?["_ga"]?.string == "GA1.1.500315824.1585154561")
        #expect(headers.cookie?["_gid"]?.string == "GA1.1.500224287.1585154561")
        #expect(headers.cookie?["!#$%&'*+-.^_`~"]?.string == "symbols")
    }

    @Test("Test Complex Cookie Parsing")
    func testCookie_complexParsing() throws {
        let headers = HTTPHeaders([
            ("cookie", "oauth2_authentication_csrf=MTU4NzA1MTc0N3xEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJRGs1WkRKbU1HRTVNMlF3TmpRM1lUbGhOelptTnprMU5EYzRZMlk1WkRObXx6lRdSC3-hPvE1pxp4ylFlBruOyJtRo8OnzBrAriBr0w==; vapor-session=ZFPQ46p3frNX52i3dM+JFlWbTxQX5rtGuQ5r7Gb6JUs=; oauth2_consent_csrf=MTU4NjkzNzgwMnxEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJR1ExWVRnM09USmhOamRsWXpSbU4yRmhOR1UwTW1KaU5tRXpPRGczTmpjMHweHbVecAf193ev3_1Tcf60iY9jSsq5-IQxGTyoztRTfg==")
        ])

        #expect(headers.cookie?["oauth2_authentication_csrf"]?.string ==
            "MTU4NzA1MTc0N3xEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJRGs1WkRKbU1HRTVNMlF3TmpRM1lUbGhOelptTnprMU5EYzRZMlk1WkRObXx6lRdSC3-hPvE1pxp4ylFlBruOyJtRo8OnzBrAriBr0w==")
        #expect(headers.cookie?["vapor-session"]?.string == "ZFPQ46p3frNX52i3dM+JFlWbTxQX5rtGuQ5r7Gb6JUs=")
        #expect(headers.cookie?["oauth2_consent_csrf"]?.string ==
            "MTU4NjkzNzgwMnxEdi1CQkFFQ180SUFBUkFCRUFBQVB2LUNBQUVHYzNSeWFXNW5EQVlBQkdOemNtWUdjM1J5YVc1bkRDSUFJR1ExWVRnM09USmhOamRsWXpSbU4yRmhOR1UwTW1KaU5tRXpPRGczTmpjMHweHbVecAf193ev3_1Tcf60iY9jSsq5-IQxGTyoztRTfg==")
    }

    @Test("Test Invalid Cookie Handling")
    func testCookie_invalidCookie() throws {
        let headers = HTTPHeaders([
            ("cookie", "cookie_one=1;cookie\ntwo=2;cookie_three=3;cookie_④=4;cookie_fivé=5")
        ])

        #expect(headers.cookie?.all.count == 2)
        #expect(headers.cookie?["cookie_one"]?.string == "1")
        #expect(headers.cookie?["cookie\ntwo"] == nil)
        #expect(headers.cookie?["cookie_three"]?.string == "3")
        #expect(headers.cookie?["cookie_④"] == nil)
        #expect(headers.cookie?["cookie_fivé"] == nil)
    }

    @Test("Test Media Type Main Type Case Insensitive")
    func testMediaTypeMainTypeCaseInsensitive() throws {
        let lower = HTTPMediaType(type: "foo", subType: "")
        let upper = HTTPMediaType(type: "FOO", subType: "")
        #expect(lower == upper)
    }

    @Test("Test Media Type Sub Type Case Insensitive")
    func testMediaTypeSubTypeCaseInsensitive() throws {
        let lower = HTTPMediaType(type: "foo", subType: "bar")
        let upper = HTTPMediaType(type: "foo", subType: "BAR")
        #expect(lower == upper)
    }

    @Test("Test Content-Disposition with Quoted Filename", .bug("https://github.com/vapor/vapor/issues/2439"))
    func testContentDispositionQuotedFilename() throws {
        var headers = HTTPHeaders()

        headers.contentDisposition = .init(.formData, filename: "foo")
        #expect(headers.first(name: .contentDisposition) == "form-data; filename=\"foo\"")

        headers.contentDisposition = .init(.formData, filename: "foo bar")
        #expect(headers.first(name: .contentDisposition) == #"form-data; filename="foo bar""#)

        headers.contentDisposition = .init(.formData, filename: "foo\"bar")
        #expect(headers.first(name: .contentDisposition) == #"form-data; filename="foo\"bar""#)
    }

    @Test("Test Range Directive Serialization")
    func testRangeDirectiveSerialization() throws {
        let range = HTTPHeaders.Range(unit: .bytes, ranges: [
            .within(start: 200, end: 1000),
            .within(start: 2000, end: 6576),
            .start(value: 19000),
            .tail(value: 500)
        ])

        var headers = HTTPHeaders()
        headers.range = range

        #expect(headers.range == range)
    }

    @Test("Test Content-Range Directive Serialization")
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
        #expect(headers.contentRange == anyRange)

        headers.contentRange = rangeOfUnknownLimit
        #expect(headers.contentRange == rangeOfUnknownLimit)

        headers.contentRange = rangeWithLimit
        #expect(headers.contentRange == rangeWithLimit)
    }

    @Test("Test Range Serialization")
    func testRangeSerialization() throws {
        let range = HTTPHeaders.Range(unit: .bytes, ranges: [
            .within(start: 200, end: 1000),
            .within(start: 2000, end: 6576),
            .start(value: 19000),
            .tail(value: 500)
        ])

        #expect(range.serialize() == "bytes=200-1000, 2000-6576, 19000-, -500")
    }

    @Test("Test Range Deserialization")
    func testRangeDeserialization() throws {
        let range = HTTPHeaders.Range(unit: .bytes, ranges: [
            .within(start: 200, end: 1000),
            .within(start: 2000, end: 6576),
            .start(value: 19000),
            .tail(value: 500)
        ])

        let directives = [
            HTTPHeaders.Directive(value: "bytes", parameter: "200-1000"),
            HTTPHeaders.Directive(value: "2000-6576"),
            HTTPHeaders.Directive(value: "19000-"),
            HTTPHeaders.Directive(value: "-500"),
        ]

        #expect(HTTPHeaders.Range(directives: directives) == range)
    }

    @Test("Test Link Header Parsing")
    func testLinkHeaderParsing() throws {
        let headers = HTTPHeaders([
            ("link", #"<https://localhost/?a=1>; rel="next", <https://localhost/?a=2>; rel="last"; custom1="whatever", </?a=-1>; rel=related, </?a=-2>; rel=related"#)
        ])

        #expect(headers.links?.count == 4)

        let a = headers.links?.dropFirst(0).first
        let b = headers.links?.dropFirst(1).first
        let c = headers.links?.dropFirst(2).first
        let d = headers.links?.dropFirst(3).first

        #expect(a?.uri == "https://localhost/?a=1")
        #expect(a?.relation == .next)
        #expect(a?.attributes == [:])

        #expect(b?.uri == "https://localhost/?a=2")
        #expect(b?.relation == .last)
        #expect(b?.attributes == ["custom1": "whatever"])

        #expect(c?.uri == "/?a=-1")
        #expect(c?.relation == .related)
        #expect(c?.attributes == [:])

        #expect(d?.uri == "/?a=-2")
        #expect(d?.relation == .related)
        #expect(d?.attributes == [:])
    }

    @Test("Test Link Header Serialization")
    func testLinkHeaderSerialization() throws {
        let links: [HTTPHeaders.Link] = [
            .init(uri: "https://localhost/?a=1", relation: .next, attributes: [:]),
            .init(uri: "https://localhost/?a=2", relation: .last, attributes: ["custom1": "whatever"]),
            .init(uri: "/?a=-1", relation: .related, attributes: [:]),
            .init(uri: "/?a=-2", relation: .related, attributes: [:]),
        ]

        var headers = HTTPHeaders()
        headers.links = links

        #expect(headers.first(name: .link) == #"<https://localhost/?a=1>; rel="next", <https://localhost/?a=2>; rel="last"; custom1="whatever", </?a=-1>; rel="related", </?a=-2>; rel="related""#)
    }

    /// Test parse and serialize of `Last-Modified` header
    @Test("Test Last-Modified Header Parsing and Serialization")
    func testLastModifiedHeader() throws {
        var headers = HTTPHeaders()
        headers.lastModified = HTTPHeaders.LastModified(value: Date(timeIntervalSince1970: 18 * 3600))

        // Ensure the last-modified date was parsed correctly
        let date = try #require(headers.lastModified)

        #expect(date.value.timeIntervalSince1970 == 18 * 3600)
        #expect(date.serialize() == "Thu, 01 Jan 1970 18:00:00 GMT")
    }

    /// Test parse and serialize of `Expires` header
    @Test("Test Expires Header Parsing and Serialization")
    func testExpiresHeader() throws {
        var headers = HTTPHeaders()
        headers.expires = HTTPHeaders.Expires(expires: Date(timeIntervalSince1970: 18 * 3600))

        // Ensure the expires header was parsed correctly
        let date = try #require(headers.expires)

        #expect(date.expires.timeIntervalSince1970 == 18 * 3600)
        #expect(date.serialize() == "Thu, 01 Jan 1970 18:00:00 GMT")
    }

    /// Test parse and serialize of `Cache-Control` header
    @Test("Test Cache-Control Header Parsing and Serialization")
    func testCacheControlHeader() throws {
        var headers = HTTPHeaders()
        headers.cacheControl = HTTPHeaders.CacheControl(immutable: true)

        // Ensure the cache-control header was parsed correctly
        let cacheControl = try #require(headers.cacheControl)

        #expect(cacheControl.serialize() == "immutable")
    }

    /// Test that multiple same-named headers round-trip through Codable
    @Test("Test Codable Multiple Headers Roundtrip")
    func testCodableMultipleHeadersRountrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var headers = HTTPHeaders()
        headers.add(name: .date, value: "\(Date(timeIntervalSinceReferenceDate: 100.0))")
        headers.add(name: .date, value: "\(Date(timeIntervalSinceReferenceDate: -100.0))")
        headers.add(name: .connection, value: "be-strange")

        let encodedHeaders = try encoder.encode(headers)

        #expect(String(decoding: encodedHeaders, as: UTF8.self) == #"[{"name":"date","value":"2001-01-01 00:01:40 +0000"},{"name":"date","value":"2000-12-31 23:58:20 +0000"},{"name":"connection","value":"be-strange"}]"#)

        let decodedHeaders = try decoder.decode(HTTPHeaders.self, from: encodedHeaders)

        #expect(decodedHeaders.count == headers.count)

        for ((k1, v1), (k2, v2)) in zip(headers, decodedHeaders) {
            #expect(k1 == k2)
            #expect(v1 == v2)
        }
    }

    /// Make sure the old HTTPHeaders encoding can still be decoded
    @Test("Test Old HTTPHeaders Encoding")
    func testOldHTTPHeadersEncoding() throws {
        let decoder = JSONDecoder()
        let json = #"{"connection":"fun","attention":"none"}"#
        var headers = HTTPHeaders()

        #expect(throws: Never.self) {
            headers = try decoder.decode(HTTPHeaders.self, from: Data(json.utf8))
        }

        #expect(headers.count == 2)
        #expect(headers.first(name: "connection") == "fun")
        #expect(headers.first(name: "attention") == "none")
    }
}
