@testable import Vapor
import Testing

@Suite("Case-Insensitive ASCII Equality")
struct StringProtocolCaseInsensitiveEqualASCIITests {
    @Test("Equal ignoring ASCII letter case", arguments: [
        ("", ""),                                   // both empty
        ("hello", "hello"),                         // identical
        ("Hello", "hello"),                         // leading capital
        ("HELLO", "hello"),                         // all caps vs all lower
        ("HeLLo", "hEllO"),                         // mixed vs inverted case
        ("A", "a"),                                 // lower bound of A–Z fold range
        ("Z", "z"),                                 // upper bound of A–Z fold range
        ("application/json", "APPLICATION/JSON"),   // HTTPMediaType-style value
        ("Foo-Bar_123", "foo-bar_123"),             // only letters fold; -, _, digits stay
        ("123!@#", "123!@#"),                       // no letters at all
        ("@", "@"),                                 // non-letter equal to itself
        ("[", "["),
        ("Straße", "STRAßE"),                       // ASCII folds around a non-ASCII byte
        ("café", "café"),                           // identical non-ASCII
    ])
    func equal(_ a: String, _ b: String) {
        #expect(a.isCaseInsensitiveEqualASCII(to: b))
        #expect(b.isCaseInsensitiveEqualASCII(to: a)) // symmetric
    }

    @Test("Not equal", arguments: [
        ("hello", "world"),   // different content
        ("hello", "hell"),    // b is a prefix of a (different length)
        ("hell", "hello"),    // a is a prefix of b (different length)
        ("", "a"),            // empty vs non-empty
        ("@", "`"),           // 0x40 vs 0x60: differ by 0x20 but neither is a letter
        ("[", "{"),           // 0x5B vs 0x7B: just outside A–Z / a–z, differ by 0x20
        ("é", "e"),           // 2 UTF-8 bytes vs 1: length mismatch, not a case fold
        ("café", "CAFÉ"),     // same byte length, but É vs é is non-ASCII and not folded
        ("Ω", "ω"),           // non-ASCII case is never folded
    ])
    func notEqual(_ a: String, _ b: String) {
        #expect(!a.isCaseInsensitiveEqualASCII(to: b))
        #expect(!b.isCaseInsensitiveEqualASCII(to: a)) // symmetric
    }

    @Test("Every ASCII uppercase letter equals its lowercase counterpart")
    func allASCIILettersFold() {
        for upper in UInt8(0x41)...UInt8(0x5A) {
            let u = String(Unicode.Scalar(upper))
            let l = String(Unicode.Scalar(upper + 0x20))
            #expect(u.isCaseInsensitiveEqualASCII(to: l), "\(u) should equal \(l)")
        }
    }

    @Test("Fold applies only to A–Z, never to adjacent ASCII bytes")
    func foldRangeBoundaries() {
        // '@'(0x40) and '['(0x5B) border the A–Z range; '`'(0x60) and '{'(0x7B) border a–z.
        // None of them are letters, so a byte and the one 0x20 higher must stay distinct.
        for base: UInt8 in [0x40, 0x5B] {
            let low = String(Unicode.Scalar(base))
            let high = String(Unicode.Scalar(base + 0x20))
            #expect(!low.isCaseInsensitiveEqualASCII(to: high), "\(low) must not equal \(high)")
        }
    }

    @Test("Works across StringProtocol types")
    func mixedStringProtocolTypes() {
        let world = "Hello World".dropFirst(6) // Substring "World"
        #expect(world.isCaseInsensitiveEqualASCII(to: "world"))
        #expect("WORLD".isCaseInsensitiveEqualASCII(to: world))
        #expect(!world.isCaseInsensitiveEqualASCII(to: "word"))
    }
}
