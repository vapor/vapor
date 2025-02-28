import Vapor
import Testing
import NIOHTTP1
import Foundation

@Suite("HTTP Cache Tests")
class HTTPCacheTests {
    @Test("Test No Store With Expires")
    func testNoStoreWithExpires() {
        let requested = Date()
        var headers = HTTPFields()
        headers.add(name: .expires, value: "Sun, 06 Nov 1994 08:49:37 GMT")
        headers.add(name: .cacheControl, value: "no-store, max-age=12")

        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: requested) == nil)
    }

    @Test("Test No Store")
    func testNoStore() {
        let requested = Date()
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "no-store, max-age=12"))
        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: requested) == nil)
    }

    @Test("Test Max Age")
    func testMaxAge() {
        let seconds = Int.random(in: 1...3_000_333)
        let requested = Date()
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "max-age=\(seconds)"))
        let response = ClientResponse(status: .ok, headers: headers)

        let required = requested.addingTimeInterval(TimeInterval(seconds))

        #expect(response.headers.expirationDate(requestSentAt: requested) == required)
    }

    @Test("Test No Matching")
    func testNoMatching() {
        let requested = Date()
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "random garbage"))
        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: requested) == nil)
    }

    @Test("Test Missing Header")
    func testMissingHeader() {
        let response = ClientResponse(status: .ok)
        #expect(response.headers.expirationDate(requestSentAt: Date()) == nil)
    }

    private func dateFromFormat(format: String, dateStr: String) -> Date {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = format

        return fmt.date(from: dateStr)!
    }

    @Test("Test Preferred Format")
    func testPreferredFormat() {
        let expires = "Sun, 06 Nov 1994 08:49:37 GMT"
        let format = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let required = dateFromFormat(format: format, dateStr: expires)
        let headers = HTTPFields(dictionaryLiteral: ("Expires", expires))
        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: Date()) == required)
    }

    @Test("Test Obselete Format One")
    func testObsoleteFormatOne() {
        let expires = "Sunday, 06-Nov-94 08:49:37 GMT"
        let format = "EEEE, dd-MMM-yy HH:mm:ss zzz"
        let required = dateFromFormat(format: format, dateStr: expires)
        let headers = HTTPFields(dictionaryLiteral: ("Expires", expires))
        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: Date()) == required)
    }

    @Test("Test Obselete Format Two")
    func testObsoleteFormatTwo() {
        let expires = "Sun Nov  6 08:49:37 1994"
        let format = "EEE MMM d HH:mm:s yyyy"
        let required = dateFromFormat(format: format, dateStr: expires)
        let headers = HTTPFields(dictionaryLiteral: ("Expires", expires))
        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: Date()) == required)
    }

    @Test("Test Max Age Overrides Expires")
    func testMaxAgeOverridesExpires() {
        let requested = Date()
        let seconds = Int.random(in: 1...3_000_333)
        let required = requested.addingTimeInterval(TimeInterval(seconds))

        var headers = HTTPFields()
        headers.add(name: .expires, value: "Sun, 06 Nov 1994 08:49:37 GMT")
        headers.add(name: .cacheControl, value: "max-age=\(seconds)")

        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.expirationDate(requestSentAt: requested) == required)
    }

    @Test("Test Cache Control Flags")
    func testFlags() {
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "no-store, max-age=12"))
        let response = ClientResponse(status: .ok, headers: headers)

        #expect(response.headers.cacheControl!.noStore == true)
        #expect(response.headers.cacheControl!.immutable == false)
        #expect(response.headers.cacheControl!.maxAge == 12)
    }

    @Test("Test Max Stale Number Without Value")
    func textMaxStaleNoValue() {
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "max-stale"))
        let response = ClientResponse(status: .ok, headers: headers)

        let cache = response.headers.cacheControl!

        #expect(cache.maxStale != nil)
        #expect(cache.maxStale?.seconds == nil)
    }

    @Test("Test Max Stale Number With Value")
    func textMaxStaleWithValue() {
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "max-stale=12"))
        let response = ClientResponse(status: .ok, headers: headers)

        let cache = response.headers.cacheControl!

        #expect(cache.maxStale != nil)
        #expect(cache.maxStale?.seconds != nil)
        #expect(cache.maxStale?.seconds == 12)
    }

    @Test("Test Immutable")
    func testImmutable() {
        let headers = HTTPFields(dictionaryLiteral: ("Cache-Control", "immutable"))
        let response = ClientResponse(status: .ok, headers: headers)

        let cache = response.headers.cacheControl!
        #expect(cache.immutable == true)
    }
}
