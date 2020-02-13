import Vapor
import XCTest

class CacheTests: XCTestCase {
    func testNoStoreWithExpires() {
        let requested = Date()
        var headers = HTTPHeaders()
        headers.add(name: .expires, value: "Sun, 06 Nov 1994 08:49:37 GMT")
        headers.add(name: .cacheControl, value: "no-store, max-age=12")

        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertNil(response.headers.expirationDate(requestSentAt: requested))
    }

    func testNoStore() {
        let requested = Date()
        let headers = HTTPHeaders(dictionaryLiteral: ("Cache-Control", "no-store, max-age=12"))
        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertNil(response.headers.expirationDate(requestSentAt: requested))
    }

    func testMaxAge() {
        let seconds = Int.random(in: 1...3_000_333)
        let requested = Date()
        let headers = HTTPHeaders(dictionaryLiteral: ("Cache-Control", "max-age=\(seconds)"))
        let response = ClientResponse(status: .ok, headers: headers)

        let required = requested.addingTimeInterval(TimeInterval(seconds))

        XCTAssertEqual(response.headers.expirationDate(requestSentAt: requested), required)
    }

    func testNoMatching() {
        let requested = Date()
        let headers = HTTPHeaders(dictionaryLiteral: ("Cache-Control", "random garbage"))
        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertNil(response.headers.expirationDate(requestSentAt: requested))
    }

    func testMissingHeader() {
        let response = ClientResponse(status: .ok)
        XCTAssertNil(response.headers.expirationDate(requestSentAt: Date()))
    }

    private func dateFromFormat(format: String, dateStr: String) -> Date {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = format

        return fmt.date(from: dateStr)!
    }

    func testPreferredFormat() {
        let expires = "Sun, 06 Nov 1994 08:49:37 GMT"
        let format = "EEE, dd MMM yyyy hh:mm:ss zzz"
        let required = dateFromFormat(format: format, dateStr: expires)
        let headers = HTTPHeaders(dictionaryLiteral: ("Expires", expires))
        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertEqual(response.headers.expirationDate(requestSentAt: Date()), required)
    }

    func testObsoleteFormatOne() {
        let expires = "Sunday, 06-Nov-94 08:49:37 GMT"
        let format = "EEEE, dd-MMM-yy hh:mm:ss zzz"
        let required = dateFromFormat(format: format, dateStr: expires)
        let headers = HTTPHeaders(dictionaryLiteral: ("Expires", expires))
        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertEqual(response.headers.expirationDate(requestSentAt: Date()), required)
    }

    func testObsoleteFormatTwo() {
        let expires = "Sun Nov  6 08:49:37 1994"
        let format = "EEE MMM d hh:mm:s yyyy"
        let required = dateFromFormat(format: format, dateStr: expires)
        let headers = HTTPHeaders(dictionaryLiteral: ("Expires", expires))
        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertEqual(response.headers.expirationDate(requestSentAt: Date()), required)
    }

    func testMaxAgeOverridesExpires() {
        let requested = Date()
        let seconds = Int.random(in: 1...3_000_333)
        let required = requested.addingTimeInterval(TimeInterval(seconds))

        var headers = HTTPHeaders()
        headers.add(name: .expires, value: "Sun, 06 Nov 1994 08:49:37 GMT")
        headers.add(name: .cacheControl, value: "max-age=\(seconds)")

        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertEqual(response.headers.expirationDate(requestSentAt: requested), required)
    }

    func testFlags() {
        let headers = HTTPHeaders(dictionaryLiteral: ("Cache-Control", "no-store, max-age=12"))
        let response = ClientResponse(status: .ok, headers: headers)

        XCTAssertTrue(response.headers.cacheControl!.noStore)
        XCTAssertFalse(response.headers.cacheControl!.immutable)
        XCTAssertEqual(response.headers.cacheControl!.maxAge, 12)
    }

    func textMaxStaleNoValue() {
        let headers = HTTPHeaders(dictionaryLiteral: ("Cache-Control", "max-stale"))
        let response = ClientResponse(status: .ok, headers: headers)

        let cache = response.headers.cacheControl!

        XCTAssertNotNil(cache.maxStale)
        XCTAssertNil(cache.maxStale?.seconds)
    }

    func textMaxStaleNoWithValue() {
        let headers = HTTPHeaders(dictionaryLiteral: ("Cache-Control", "max-stale=12"))
        let response = ClientResponse(status: .ok, headers: headers)

        let cache = response.headers.cacheControl!

        XCTAssertNotNil(cache.maxStale)
        XCTAssertNotNil(cache.maxStale?.seconds)
        XCTAssertEqual(cache.maxStale?.seconds, 12)
    }
}
