@testable import Vapor
import Testing

@Suite("Utility Tests")
struct UtilityTests {
    @Test("Test hex encoding")
    func testHexEncoding() throws {
        let bytes: [UInt8] = [1, 42, 128, 240]
        #expect(bytes.hex == "012a80f0")
        #expect(bytes.hexEncodedString() == "012a80f0")
        #expect(bytes.hexEncodedString(uppercase: true) == "012A80F0")
    }

    @Test("Test hex encoding sequence")
    func testHexEncodingSequence() throws {
        let bytes: AnySequence<UInt8> = AnySequence([1, 42, 128, 240])
        #expect(bytes.hex == "012a80f0")
        #expect(bytes.hexEncodedString() == "012a80f0")
        #expect(bytes.hexEncodedString(uppercase: true) == "012A80F0")
    }

    @Test("Test Byte Count")
    func testByteCount() throws {
        let twoKbUpper: ByteCount = "2 KB"
        #expect(twoKbUpper.value == 2_048)

        let twoKb: ByteCount = "2kb"
        #expect(twoKb.value == 2_048)

        let oneMb: ByteCount = "1mb"
        #expect(oneMb.value == 1_048_576)

        let oneGb: ByteCount = "1gb"
        #expect(oneGb.value == 1_073_741_824)

        let oneTb: ByteCount = "1tb"
        #expect(oneTb.value == 1_099_511_627_776)

        let intBytes: ByteCount = 1_000_000
        #expect(intBytes.value == 1_000_000)
    }
}
