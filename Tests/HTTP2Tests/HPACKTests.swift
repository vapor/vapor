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
    func testHeaderDecoding0() throws {
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
    
    func testHeaderDecoding1() throws {
        let encodedHeaders = Data([
            0x04, 0x0c, 0x2f, 0x73, 0x61, 0x6d, 0x70,
            0x6c, 0x65, 0x2f, 0x70, 0x61, 0x74, 0x68
        ])
        
        let headers = try HPACKDecoder().decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":path"], "/sample/path")
    }
    
    func testHeaderDecoding2() throws {
        let encodedHeaders = Data([
            0x10, 0x08, 0x70, 0x61, 0x73, 0x73,
            0x77, 0x6f, 0x72, 0x64, 0x06, 0x73,
            0x65, 0x63, 0x72, 0x65, 0x74
        ])
        
        let headers = try HPACKDecoder().decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers["password"], "secret")
    }
    
    func testHeaderDecoding3() throws {
        let encodedHeaders = Data([
            0x82
        ])
        
        let headers = try HPACKDecoder().decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
    }
    
    // http://httpwg.org/specs/rfc7541.html#request.examples.without.huffman.coding
    func testPlainMultiHeaderRequestDecoding() throws {
        let decoder = HPACKDecoder()
        
        var encodedHeaders = Data([
            0x82, 0x86, 0x84, 0x41, 0x0f,
            0x77, 0x77, 0x77, 0x2e, 0x65,
            0x78, 0x61, 0x6d, 0x70, 0x6c,
            0x65, 0x2e, 0x63, 0x6f, 0x6d
        ])
        
        var headers = try decoder.decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        
        encodedHeaders = Data([
            0x82, 0x86, 0x84, 0xbe,
            0x58, 0x08, 0x6e, 0x6f,
            0x2d, 0x63, 0x61, 0x63,
            0x68, 0x65
        ])
        
        headers = try decoder.decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers[.cacheControl], "no-cache")
        
        encodedHeaders = Data([
            0x82, 0x87, 0x85, 0xbf,
            0x40, 0x0a, 0x63, 0x75,
            0x73, 0x74, 0x6f, 0x6d,
            0x2d, 0x6b, 0x65, 0x79,
            0x0c, 0x63, 0x75, 0x73,
            0x74, 0x6f, 0x6d, 0x2d,
            0x76, 0x61, 0x6c, 0x75,
            0x65
        ])
        
        headers = try decoder.decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "https")
        XCTAssertEqual(headers[":path"], "/index.html")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers["custom-key"], "custom-value")
    }
    
    // http://httpwg.org/specs/rfc7541.html#request.examples.with.huffman.coding
    func testHuffmanMultiHeaderRequestDecoding() throws {
        let decoder = HPACKDecoder()
        
        var encodedHeaders = Data([
            0x82, 0x86, 0x84, 0x41,
            0x8c, 0xf1, 0xe3, 0xc2,
            0xe5, 0xf2, 0x3a, 0x6b,
            0xa0, 0xab, 0x90, 0xf4,
            0xff
            ])
        
        var headers = try decoder.decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        
        encodedHeaders = Data([
            0x82, 0x86, 0x84, 0xbe,
            0x58, 0x86, 0xa8, 0xeb,
            0x10, 0x64, 0x9c, 0xbf
        ])
        
        headers = try decoder.decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers[.cacheControl], "no-cache")
        
        encodedHeaders = Data([
            0x82, 0x87, 0x85, 0xbf,
            0x40, 0x88, 0x25, 0xa8,
            0x49, 0xe9, 0x5b, 0xa9,
            0x7d, 0x7f, 0x89, 0x25,
            0xa8, 0x49, 0xe9, 0x5b,
            0xb8, 0xe8, 0xb4, 0xbf
        ])
        
        headers = try decoder.decode(Packet(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "https")
        XCTAssertEqual(headers[":path"], "/index.html")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers["custom-key"], "custom-value")
    }
    
    func testHeaderDecodingFailure0() throws {
        let encodedHeaders = Data([
            0x82, 0x86, 0x84, 0x41, 0x0f,
            0x77, 0x77, 0x77, 0x2e, 0x65,
            0x78, 0x61, 0x6d, 0x70, 0x6c,
            0x65, 0x2e, 0x63, 0x6f
        ])
        
        XCTAssertThrowsError(try HPACKDecoder().decode(Packet(data: encodedHeaders)))
    }
    
    func testConstants() {
        XCTAssertEqual(HeadersTable.staticEntries.count, 61)
    }
}
