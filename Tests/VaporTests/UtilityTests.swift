import XCTVapor
@testable import Vapor
import XCTest

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
