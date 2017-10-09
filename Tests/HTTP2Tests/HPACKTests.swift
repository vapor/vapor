import XCTest
@testable import HTTP2
import Pufferfish

public class HPACKTests: XCTestCase {
    /// http://httpwg.org/specs/rfc7541.html#rfc.section.C.1.1
    func testHPackIntegerParsing() throws {
        // First 3 bits don't matter in a 5-bit prefix
        let ten0: UInt8 = 0b00001010
        let ten1: UInt8 = 0b11001010
        let ten2: UInt8 = 0b10101010
        let ten3: UInt8 = 0b01101010
        let ten4: UInt8 = 0b10001010
        let ten5: UInt8 = 0b00101010
        let ten6: UInt8 = 0b01001010
        let ten7: UInt8 = 0b11101010
        
        let cases = [ten0, ten1, ten2, ten3, ten4, ten5, ten6, ten7]
        
        for testCase in cases {
            let packet = Packet(data: Data([testCase]))
            
            let number = try packet.parseInteger(prefix: 5)
            
            XCTAssertEqual(number, 10)
        }
        
        let elevenPacket = Packet(data: Data([11]))
        let twelvePacket = Packet(data: Data([12]))
        
        let eleven = try elevenPacket.parseInteger(prefix: 4)
        let twelve = try twelvePacket.parseInteger(prefix: 4)
        
        XCTAssertEqual(eleven, 11)
        XCTAssertEqual(twelve, 12)
    }
    
    func testIntegerSerialization() throws {
        let message = Packet()
        try message.append(integer: 1337, prefix: 5)
        
        let leetPacket = Packet(data: Data([0b00011111, 0b10011010, 0b00001010]))
        XCTAssertEqual(message.data, leetPacket.data)
    }
    
    /// http://httpwg.org/specs/rfc7541.html#rfc.section.C.1.2
    func testMultilineHPPACKIntegers() throws {
        let leetPacket = Packet(data: Data([0b00011111, 0b10011010, 0b00001010]))
        
        let leet = try leetPacket.parseInteger(prefix: 5)
        
        XCTAssertEqual(leet, 1337)
    }
    
    func testHuffmanStringSerialization() throws {
        let string = "302"
        
        let data = Array(try HuffmanEncoder.hpack.encode(string: string))
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data, [0x64, 0x02])
    }
    
    func testHuffmanStringParsing() throws {
        let data = Data([0x64, 0x02])
        
        let decoded = try HuffmanDecoder.hpack().decode(data: data)
        let string = String(bytes: decoded, encoding: .utf8)
        XCTAssertEqual(string, "302")
    }
    
    func testHuffmanStrings() throws {
        let string = "302"
        
        let data = try HuffmanEncoder.hpack.encode(string: string)
        let sameString = String(bytes: try HuffmanDecoder.hpack().decode(data: data), encoding: .utf8)
        
        XCTAssertEqual(sameString, "302")
    }
    
    // http://httpwg.org/specs/rfc7541.html#rfc.section.C.2.1
    func testHeaderDecoding() throws {
        let encodedHeaders = Data([
            0x40, 0x0a, 0x63, 0x75,
            0x73, 0x74, 0x6f, 0x6d,
            0x2d, 0x6b, 0x65, 0x79,
            0x0d, 0x63, 0x75, 0x73,
            0x74, 0x6f, 0x6d, 0x2d,
            0x68, 0x65, 0x61, 0x64,
            0x65, 0x72
        ])
        
        let headers = try HPACKDecoder().decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers["custom-key"], "custom-header")
    }
    
    func testConstants() {
        XCTAssertEqual(HeadersTable.staticEntries.count, 61)
    }
}
