#if canImport(FoundationEssentials)
import FoundationEssentials
@testable import Vapor
import Testing

// We only run these on Linux with FoundationEssentials since we don't
// need to test Foundation's `removingPercentEncoding`
@Suite("Removing Percent Encoding")
struct StringRemovingPercentEncodingTests {
    @Test("Decodes percent escapes", arguments: [
        ("", ""),                                        // empty input
        ("hello", "hello"),                              // nothing to decode
        ("hello%20world", "hello world"),                // single escape mid-string
        ("%20", " "),                                    // lone escape
        ("%2F", "/"),                                    // uppercase hex
        ("%2f", "/"),                                    // lowercase hex
        ("%3D%3d", "=="),                                // mixed hex case
        ("%25", "%"),                                    // literal percent
        ("100%25", "100%"),                              // percent at end of text
        ("%48%65%6C%6C%6F", "Hello"),                    // back-to-back escapes
        ("a+b", "a+b"),                                  // '+' is NOT decoded to space
        ("%00", "\u{0}"),                                // NUL is valid UTF-8
        ("caf%C3%A9", "café"),                           // multi-byte UTF-8 sequence
        ("%E2%9C%93", "\u{2713}"),                        // 3-byte UTF-8 (✓)
        ("%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82", "Привет"), // non-Latin script
        ("caf\u{e9}", "caf\u{e9}"),                       // already-decoded unicode passes through
    ])
    func decodes(_ input: String, _ expected: String) {
        #expect(input.removingPercentEncoding == expected)
    }

    @Test("Returns nil on malformed input", arguments: [
        "%",        // '%' with nothing after it
        "%2",       // '%' with only one trailing char
        "abc%",     // trailing '%'
        "ab%c",     // '%' followed by one hex then end
        "%GG",      // non-hex high nibble
        "%2G",      // non-hex low nibble
        "%ZZ",      // non-hex both
        "% 0",      // space is not hex
        "%FF",      // 0xFF alone is not valid UTF-8
        "%C3",      // truncated 2-byte UTF-8 sequence
        "%C3%28",   // 0xC3 followed by a non-continuation byte
        "%E2%9C",   // truncated 3-byte UTF-8 sequence
    ])
    func returnsNilOnMalformed(_ input: String) {
        #expect(input.removingPercentEncoding == nil)
    }

    @Test("Round-trips arbitrary strings encoded byte-by-byte")
    func roundTrip() {
        // Percent-encode every UTF-8 byte
        let hex = Array("0123456789ABCDEF".utf8)
        func encodeEveryByte(_ value: String) -> String {
            var out: [UInt8] = []
            for byte in value.utf8 {
                out.append(0x25) // '%'
                out.append(hex[Int(byte >> 4)])
                out.append(hex[Int(byte & 0x0F)])
            }
            return String(decoding: out, as: UTF8.self)
        }

        for value in ["", "a b", "100%", "/path?q=x&y=z", "café ☕️", "π=3.14", "a\u{0}b"] {
            #expect(encodeEveryByte(value).removingPercentEncoding == value)
        }
    }
}
#endif
