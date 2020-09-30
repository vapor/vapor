import Vapor
import XCTest

final class OTPTests: XCTestCase {
    /// Basic TOTP tests using some RFC 6238 test vectors.
    /// https://tools.ietf.org/html/rfc6238.html
    func testTOTPBasic() {
        let time = Date(timeIntervalSince1970: 59)
        var key: SymmetricKey
        
        // SHA-1 test
        key = SymmetricKey(data: "12345678901234567890".data(using: .ascii)!)
        let sha1OTP = TOTP.SHA1(key: key, digits: .eight, interval: 30).generate(time: time)
        XCTAssertEqual(sha1OTP, "94287082")
        
        // SHA-256 test
        key = SymmetricKey(data: "12345678901234567890123456789012".data(using: .ascii)!)
        let sha256OTP = TOTP.SHA256(key: key, digits: .eight, interval: 30).generate(time: time)
        XCTAssertEqual(sha256OTP, "46119246")
        
        // SHA-512 test
        key = SymmetricKey(data: "1234567890123456789012345678901234567890123456789012345678901234".data(using: .ascii)!)
        let sha512OTP = TOTP.SHA512(key: key, digits: .eight, interval: 30).generate(time: time)
        XCTAssertEqual(sha512OTP, "90693936")
        
    }
    
    /// Basic TOTP test using the range, copied from Vapor 3.
    /// https://github.com/vapor/open-crypto/blob/38487c8eb13d689d0ed6b3808a9a9bc00cd621f6/Tests/CryptoTests/OTPTests.swift
    func testTOTPRange() {
        let key = SymmetricKey(size: .bits128)
        let codes = TOTP.SHA1(key: key).generate(time: Date(), range: 1)
        XCTAssertEqual(codes.count, 3)
    }
    
    /// A HOTP test vector.
    typealias HOTPTest = (counter: UInt64, otp: String)
    
    /// Basic HOTP tests using RFC 4226 test vectors.
    /// https://tools.ietf.org/html/rfc4226#page-32
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
            let hotp = HOTP.SHA1(key: key).generate(counter: test.counter)
            XCTAssertEqual(hotp, test.otp)
        }
    }
    
    func testHOTPRange() {
        let key = SymmetricKey(size: .bits128)
        let codes = HOTP.SHA1(key: key).generate(counter: 10, range: 1)
        XCTAssertEqual(codes.count, 3)
    }
    
    static var allTests = [
        ("testTOTPBasic", testTOTPBasic),
        ("testHOTPBasic", testHOTPBasic)
    ]
}
