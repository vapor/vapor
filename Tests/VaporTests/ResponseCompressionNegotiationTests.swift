#if Compression
import Testing
@testable import Vapor

@Suite("Response Compression Negotiation", .timeLimit(.minutes(1)))
struct ResponseCompressionNegotiationTests {
    typealias Result = ResponseCompressionMiddleware.NegotiationResult

    @Test(
        "Accept-Encoding preferences and exclusions",
        arguments: [
            (nil, .identity), ("", .identity), (" \t", .identity), (",,,", .identity),
            ("gzip", .compress(.gzip)), ("deflate", .compress(.deflate)), ("identity", .identity),
            ("GZip", .compress(.gzip)), ("DEFLATE", .compress(.deflate)),
            (" \tgzip \t", .compress(.gzip)), (",, gzip,, ,", .compress(.gzip)),
            ("gzip, deflate", .compress(.gzip)), ("deflate, gzip", .compress(.gzip)),
            ("deflate;q=0.8, gzip;q=0.5", .compress(.deflate)),
            ("gzip;q=0.8, deflate;q=0.5", .compress(.gzip)),
            ("gzip;q=0.001", .compress(.gzip)), ("gzip;q=0.", .identity),
            ("gzip;q=1.", .compress(.gzip)), ("gzip;q=1.000", .compress(.gzip)),
            ("gzip \t; \tQ=0.500 \t, deflate;q=0.499", .compress(.gzip)),
            ("gzip;q=0", .identity), ("gzip;q=0.000", .identity),
            ("gzip;q=0, deflate;q=0", .identity),
            ("br", .identity), ("x-gzip", .identity), ("gzip-extra", .identity),
            ("gzip/deflate", .identity), ("\"gzip\"", .identity),
            ("br;q=1, gzip;q=0.1", .compress(.gzip)),
            ("*", .compress(.gzip)), ("*;q=0.001", .compress(.gzip)),
            ("*;q=0", .notAcceptable), ("*;q=0, identity;q=1", .identity),
            ("gzip;q=0, *;q=1", .compress(.deflate)),
            ("*;q=1, gzip;q=0", .compress(.deflate)),
            ("deflate;q=0, *;q=1", .compress(.gzip)),
            ("*;q=0, gzip;q=1", .compress(.gzip)),
            ("*;q=0, deflate;q=1", .compress(.deflate)),
            ("*;q=1, gzip;q=0, deflate;q=0", .identity),
            ("gzip;q=0.2, *;q=0.5", .compress(.deflate)),
            ("gzip;q=0.8, identity;q=1", .identity),
            ("gzip;q=0.8, identity;q=0.5", .compress(.gzip)),
            ("gzip;q=0.5, identity;q=0.5", .compress(.gzip)),
            ("gzip, identity;q=0", .compress(.gzip)),
            ("identity;q=0", .notAcceptable), ("br, identity;q=0", .notAcceptable),
            ("gzip;q=0, deflate;q=0, identity;q=0", .notAcceptable),
            ("*;q=0, identity;q=0.001", .identity),
            ("identity;q=0, *;q=0.1", .compress(.gzip)),
            ("gzip, gzip", .compress(.gzip)),
            ("gzip;q=0, gzip;q=1", .identity), ("gzip;q=1, gzip;q=0", .identity),
            ("gzip;q=0, GZIP", .identity),
            ("gzip;q=0.2, gzip;q=0.8, deflate;q=0.5", .compress(.deflate)),
            ("gzip;q=0.8, gzip;q=0.2, deflate;q=0.5", .compress(.deflate)),
            ("*;q=1, *;q=0", .notAcceptable), ("*;q=0, *;q=1", .notAcceptable),
            ("identity;q=0, identity;q=1", .notAcceptable),
            ("identity;q=1, identity;q=0", .notAcceptable),
            (";", .identity), (";q=1", .identity), ("=", .identity),
            ("\r\ngzip", .identity), ("gzip\u{00A0}", .identity),
            ("gzi\u{200B}p", .identity), ("gzíp", .identity), ("💥", .identity),
        ] as [(String?, Result)])
    func preferences(header: String?, expected: Result) {
        #expect(ResponseCompressionMiddleware.negotiate(header) == expected)
    }

    @Test(
        "Malformed parameters cannot enable a coding, even through a wildcard or duplicate",
        arguments: [
            "", ";", "q", "q=", "q==1", "q=garbage", "q=NaN", "q=nan", "q=inf", "q=-inf",
            "q=2", "q=-1", "q=-0", "q=+1", "q=+0.5", "q=.5", "q=00", "q=01", "q=01.0",
            "q=1e0", "q=0.5e0", "q=0x1p0", "q=1.001", "q=0.0001", "q=1.0000",
            "q= 1", "q =1", "q=\t1", "q=\"1\"", "q=１", "q=٠.٥", "q=1\u{00A0}",
            "q=1\r\n", "q=1\0", "q=1;", "q=0;q=1", "q=1;q=0", "q=1;foo=bar", "foo=bar",
        ])
    func malformedParameters(parameter: String) {
        #expect(ResponseCompressionMiddleware.negotiate("gzip;" + parameter) == .identity)
        #expect(ResponseCompressionMiddleware.negotiate("*;q=1, gzip;" + parameter) == .compress(.deflate))
        #expect(ResponseCompressionMiddleware.negotiate("gzip;" + parameter + ", gzip;q=1") == .identity)
    }

    @Test("Every valid thousandth is accepted and ranked correctly")
    func qualityBoundaries() {
        for quality in 0...1000 {
            let digits = String(quality)
            let value = quality == 1000 ? "1.000" : "0." + String(repeating: "0", count: 3 - digits.count) + digits
            let header = "gzip;q=" + value
            #expect(ResponseCompressionMiddleware.negotiate(header) == (quality == 0 ? .identity : .compress(.gzip)))
            #expect(
                ResponseCompressionMiddleware.negotiate(header + ", deflate;q=0.500")
                    == (quality >= 500 ? .compress(.gzip) : .compress(.deflate)))
            #expect(
                ResponseCompressionMiddleware.negotiate(header + ", identity;q=0.500")
                    == (quality >= 500 ? .compress(.gzip) : .identity))
        }
    }

    @Test("Long values and lists remain safe to parse")
    func longInput() {
        #expect(ResponseCompressionMiddleware.negotiate("gzip;q=" + String(repeating: "9", count: 65_536)) == .identity)
        #expect(ResponseCompressionMiddleware.negotiate("gzip;" + String(repeating: ";", count: 65_536)) == .identity)
        #expect(ResponseCompressionMiddleware.negotiate(String(repeating: ",", count: 65_536)) == .identity)
        let unknowns = (0..<4096).map { "unknown-\($0);q=1" }.joined(separator: ",")
        #expect(ResponseCompressionMiddleware.negotiate(unknowns + ", deflate;q=0.5") == .compress(.deflate))
        #expect(ResponseCompressionMiddleware.negotiate(String(repeating: "gzip,", count: 4096) + "gzip;q=0") == .identity)
    }
}
#endif
