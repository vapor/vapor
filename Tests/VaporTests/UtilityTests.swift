import XCTVapor
@testable import Vapor

final class UtilityTests: XCTestCase {
    func testHexEncoding() throws {
        let bytes: [UInt8] = [1, 42, 128, 240]
        XCTAssertEqual(bytes.hex, "012a80f0")
        XCTAssertEqual(bytes.hexEncodedString(), "012a80f0")
        XCTAssertEqual(bytes.hexEncodedString(uppercase: true), "012A80F0")
    }

    func testHexEncodingSequence() throws {
        let bytes: AnySequence<UInt8> = AnySequence([1, 42, 128, 240])

        XCTAssertEqual(bytes.hex, "012a80f0")
        XCTAssertEqual(bytes.hexEncodedString(), "012a80f0")
        XCTAssertEqual(bytes.hexEncodedString(uppercase: true), "012A80F0")
    }

    func testBase32() throws {
        // Base32 test vectors from [RFC 4648 § 10](https://datatracker.ietf.org/doc/html/rfc4648#section-10)
        // Padding requirement removed
        XCTAssertEqual("".base32String, "")
        XCTAssertEqual("f".base32String, "MY")
        XCTAssertEqual("fo".base32String, "MZXQ")
        XCTAssertEqual("foo".base32String, "MZXW6")
        XCTAssertEqual("foob".base32String, "MZXW6YQ")
        XCTAssertEqual("fooba".base32String, "MZXW6YTB")
        XCTAssertEqual("foobar".base32String, "MZXW6YTBOI")

        XCTAssertEqual(Array(base32: "").map { String(decoding: $0, as: UTF8.self) }, "")
        XCTAssertEqual(Array(base32: "MY").map { String(decoding: $0, as: UTF8.self) }, "f")
        XCTAssertEqual(Array(base32: "MZXQ").map { String(decoding: $0, as: UTF8.self) }, "fo")
        XCTAssertEqual(Array(base32: "MZXW6").map { String(decoding: $0, as: UTF8.self) }, "foo")
        XCTAssertEqual(Array(base32: "MZXW6YQ").map { String(decoding: $0, as: UTF8.self) }, "foob")
        XCTAssertEqual(Array(base32: "MZXW6YTB").map { String(decoding: $0, as: UTF8.self) }, "fooba")
        XCTAssertEqual(Array(base32: "MZXW6YTBOI").map { String(decoding: $0, as: UTF8.self) }, "foobar")

        let data = Data([1, 2, 3, 4])
        XCTAssertEqual(data.base32EncodedString(), "AEBAGBA")
        XCTAssertEqual(Data(base32Encoded: "AEBAGBA"), data)
        XCTAssertNil(Data(base32Encoded: data.base64EncodedString()))
    }
    
    func testBase64() throws {
        // Base64 test vectors from [RFC 4648 § 10](https://datatracker.ietf.org/doc/html/rfc4648#section-10)
        XCTAssertEqual("".base64String, "")
        XCTAssertEqual("f".base64String, "Zg==")
        XCTAssertEqual("fo".base64String, "Zm8=")
        XCTAssertEqual("foo".base64String, "Zm9v")
        XCTAssertEqual("foob".base64String, "Zm9vYg==")
        XCTAssertEqual("fooba".base64String, "Zm9vYmE=")
        XCTAssertEqual("foobar".base64String, "Zm9vYmFy")

        XCTAssertEqual(Array(base64: "").map { String(decoding: $0, as: UTF8.self) }, "")
        XCTAssertEqual(Array(base64: "Zg==").map { String(decoding: $0, as: UTF8.self) }, "f")
        XCTAssertEqual(Array(base64: "Zm8=").map { String(decoding: $0, as: UTF8.self) }, "fo")
        XCTAssertEqual(Array(base64: "Zm9v").map { String(decoding: $0, as: UTF8.self) }, "foo")
        XCTAssertEqual(Array(base64: "Zm9vYg==").map { String(decoding: $0, as: UTF8.self) }, "foob")
        XCTAssertEqual(Array(base64: "Zm9vYmE=").map { String(decoding: $0, as: UTF8.self) }, "fooba")
        XCTAssertEqual(Array(base64: "Zm9vYmFy").map { String(decoding: $0, as: UTF8.self) }, "foobar")
    }

    func testByteCount() throws {
        let twoKbUpper: ByteCount = "2 KB"
        XCTAssertEqual(twoKbUpper.value, 2_048)

        let twoKb: ByteCount = "2kb"
        XCTAssertEqual(twoKb.value, 2_048)

        let oneMb: ByteCount = "1mb"
        XCTAssertEqual(oneMb.value, 1_048_576)

        let oneGb: ByteCount = "1gb"
        XCTAssertEqual(oneGb.value, 1_073_741_824)

        let oneTb: ByteCount = "1tb"
        XCTAssertEqual(oneTb.value, 1_099_511_627_776)

        let intBytes: ByteCount = 1_000_000
        XCTAssertEqual(intBytes.value, 1_000_000)
    }
}
