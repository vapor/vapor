#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import Vapor
import Testing

@Suite("RFC 1123 Date")
struct DateRFC1123Tests {
    @Test("Formats known instants", arguments: [
        (0.0, "Thu, 01 Jan 1970 00:00:00 GMT"),          // Unix epoch
        (784_111_777.0, "Sun, 06 Nov 1994 08:49:37 GMT"), // the RFC 9110 example
        (1_000_000_000.0, "Sun, 09 Sep 2001 01:46:40 GMT"),
    ])
    func formats(_ timestamp: Double, _ expected: String) {
        #expect(Date(timeIntervalSince1970: timestamp).formatted(.rfc1123) == expected)
    }

    @Test("Formatted output is always 29 characters")
    func formattedLength() {
        for timestamp in stride(from: 0.0, through: 4_000_000_000, by: 50_000_000) {
            #expect(Date(timeIntervalSince1970: timestamp).formatted(.rfc1123).count == 29)
        }
    }

    @Test("Weekday is computed from the date, for consecutive days")
    func weekdays() {
        // 1970-01-01 (the epoch) is a Thursday.
        let names = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
        for offset in 0..<7 {
            let date = Date(timeIntervalSince1970: Double(offset) * 86_400)
            #expect(date.formatted(.rfc1123).hasPrefix(names[offset] + ", "))
        }
    }

    @Test("Parses all three HTTP date formats to the same instant")
    func parsesThreeFormats() throws {
        let expected = 784_111_777.0 // Sun, 06 Nov 1994 08:49:37 GMT
        let forms = [
            "Sun, 06 Nov 1994 08:49:37 GMT",   // IMF-fixdate (RFC 1123, preferred)
            "Sunday, 06-Nov-94 08:49:37 GMT",  // RFC 850 (obsolete)
            "Sun Nov  6 08:49:37 1994",        // asctime (two spaces before a single-digit day)
            "Sun Nov 6 08:49:37 1994",         // asctime with collapsed whitespace
        ]
        for form in forms {
            #expect(try Date(form, strategy: .rfc1123).timeIntervalSince1970 == expected)
        }
    }

    @Test("Ignores the weekday token when parsing")
    func ignoresWeekday() throws {
        // 06 Nov 1994 was a Sunday; claim Monday. The parser must ignore the weekday,
        // and formatting must recompute the correct one.
        let date = try Date("Mon, 06 Nov 1994 08:49:37 GMT", strategy: .rfc1123)
        #expect(date.timeIntervalSince1970 == 784_111_777)
        #expect(date.formatted(.rfc1123) == "Sun, 06 Nov 1994 08:49:37 GMT")
    }

    @Test("RFC 850 two-digit year pivots at 70", arguments: [
        ("Sunday, 01-Jan-69 00:00:00 GMT", " 2069 "),
        ("Sunday, 01-Jan-70 00:00:00 GMT", " 1970 "),
        ("Sunday, 01-Jan-99 00:00:00 GMT", " 1999 "),
        ("Sunday, 01-Jan-00 00:00:00 GMT", " 2000 "),
    ])
    func rfc850YearPivot(_ input: String, _ expectedYear: String) throws {
        #expect(try Date(input, strategy: .rfc1123).formatted(.rfc1123).contains(expectedYear))
    }

    @Test("All twelve month names round-trip through parse and format", arguments: Array(1...12))
    func monthNames(_ month: Int) throws {
        let name = Date.RFC1123FormatStyle.monthNames[month - 1]
        let parsed = try Date("Mon, 15 \(name) 2021 12:00:00 GMT", strategy: .rfc1123)
        #expect(parsed.formatted(.rfc1123).contains(" \(name) "))
    }

    @Test("Throws on malformed input", arguments: [
        "",                                 // no tokens
        "garbage",                          // one token
        "one two three",                    // wrong token count
        "Sun, 06 Xyz 1994 08:49:37 GMT",    // unknown month name
        "Sun, 06 Nov 1994 08:49 GMT",       // time missing seconds
        "Sun, XX Nov 1994 08:49:37 GMT",    // non-numeric day
        "Sunday, 06Nov94 08:49:37 GMT",     // RFC 850 date not dash-separated
        "Sunday, 06-Nov 08:49:37 GMT",      // RFC 850 date missing a component
    ])
    func throwsOnMalformed(_ input: String) {
        #expect(throws: Date.RFC1123ParseStrategy.ParseError.self) {
            try Date(input, strategy: .rfc1123)
        }
    }

    // MARK: Round-trip

    @Test("Round-trips format -> parse -> format across a wide range")
    func roundTrip() throws {
        var timestamp = 0.0
        while timestamp < 4_000_000_000 {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatted = date.formatted(.rfc1123)
            let parsed = try Date(formatted, strategy: .rfc1123)
            #expect(parsed.timeIntervalSince1970 == timestamp)      // whole seconds preserved
            #expect(parsed.formatted(.rfc1123) == formatted)        // stable
            timestamp += 3_215_777 // an odd, non-day-aligned step to vary all fields
        }
    }
}
