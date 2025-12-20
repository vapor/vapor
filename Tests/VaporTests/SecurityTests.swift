import Vapor
import Testing
import Crypto
import Foundation

@Suite("OTP Tests")
struct OTPTests {
    /// Basic TOTP tests using some RFC 6238 test vectors.
    /// https://tools.ietf.org/html/rfc6238.html
    @Test("Test TOTP")
    func testTOTPBasic() {
        let time = Date(timeIntervalSince1970: 59)
        var key: SymmetricKey

        // SHA-1 test
        key = SymmetricKey(data: "12345678901234567890".data(using: .ascii)!)
        let sha1OTP = TOTP(key: key, digest: .sha1, digits: .eight, interval: 30).generate(time: time)
        #expect(sha1OTP == "94287082")

        // SHA-256 test
        key = SymmetricKey(data: "12345678901234567890123456789012".data(using: .ascii)!)
        let sha256OTP = TOTP(key: key, digest: .sha256, digits: .eight, interval: 30).generate(time: time)
        #expect(sha256OTP == "46119246")

        // SHA-512 test
        key = SymmetricKey(data: "1234567890123456789012345678901234567890123456789012345678901234".data(using: .ascii)!)
        let sha512OTP = TOTP(key: key, digest: .sha512, digits: .eight, interval: 30).generate(time: time)
        #expect(sha512OTP == "90693936")

    }

    /// Basic TOTP test using the range, copied from Vapor 3.
    /// https://github.com/vapor/open-crypto/blob/38487c8eb13d689d0ed6b3808a9a9bc00cd621f6/Tests/CryptoTests/OTPTests.swift
    ///
    /// Test amended due to https://github.com/vapor/vapor/pull/2561
    @Test("Test TOTP with Range")
    func testTOTPRange() {
        let time = Date(timeIntervalSince1970: 60)
        let preTime = Date(timeIntervalSince1970: 30)
        let postTime = Date(timeIntervalSince1970: 90)

        let key = SymmetricKey(data: "12345678901234567890".data(using: .ascii)!)
        let totp = TOTP(key: key, digest: .sha1, digits: .eight, interval: 30)
        let codes = totp.generate(time: time, range: 1)
        #expect(codes.count == 3)

        let cur = totp.generate(time: time)
        let pre = totp.generate(time: preTime)
        let post = totp.generate(time: postTime)

        #expect(Set([cur, pre, post]).count == 3)
        #expect(codes.contains(totp.generate(time: time)))
        #expect(codes.contains(totp.generate(time: preTime)))
        #expect(codes.contains(totp.generate(time: postTime)))
    }

    /// A HOTP test vector.
    typealias HOTPTest = (counter: UInt64, otp: String)

    /// Basic HOTP tests using RFC 4226 test vectors.
    /// https://tools.ietf.org/html/rfc4226#page-32
    @Test("Test HOTP")
    func testHOTPBasic() {
        let tests: [HOTPTest] = [
            (0, "755224"),
            (1, "287082"),
            (2, "359152"),
            (3, "969429"),
            (4, "338314"),
            (5, "254676"),
            (6, "287922"),
            (7, "162583"),
            (8, "399871"),
            (9, "520489")
        ]

        let key = SymmetricKey(data: "12345678901234567890".data(using: .ascii)!)

        for test in tests {
            let hotp = HOTP(key: key, digest: .sha1).generate(counter: test.counter)
            #expect(hotp == test.otp)
        }
    }

    @Test("Test HOTP with Range")
    func testHOTPRange() {
        let key = SymmetricKey(size: .bits128)
        let codes = HOTP(key: key, digest: .sha1).generate(counter: 10, range: 1)
        #expect(codes.count == 3)
    }
}
