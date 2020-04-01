import XCTVapor

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
        let data = Data([1, 2, 3, 4])
        XCTAssertEqual(data.base32EncodedString(), "AEBAGBA")
        XCTAssertEqual(Data(base32Encoded: "AEBAGBA"), data)
    }
}
