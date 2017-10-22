import XCTest
@testable import HTTP2
import Pufferfish

public class HPACKTests: XCTestCase {
    static let allTests = [
        ("testHPackIntegerParsing", testHPackIntegerParsing),
        ("testIntegerSerialization", testIntegerSerialization),
        ("testMultilineHPPACKIntegers", testMultilineHPPACKIntegers),
        ("testHuffmanStringSerialization", testHuffmanStringSerialization),
        ("testHuffmanStringParsing", testHuffmanStringParsing),
        ("testHuffmanStrings", testHuffmanStrings),
        ("testHeaderDecoding0", testHeaderDecoding0),
        ("testHeaderDecoding1", testHeaderDecoding1),
        ("testHeaderDecoding2", testHeaderDecoding2),
        ("testHeaderDecoding3", testHeaderDecoding3),
        ("testHeaderEncoding0", testHeaderEncoding0),
        ("testHeaderEncoding1", testHeaderEncoding1),
        ("testHeaderEncoding2", testHeaderEncoding2),
        ("testHeaderEncoding3", testHeaderEncoding3),
        ("testPlainMultiHeaderRequestDecoding", testPlainMultiHeaderRequestDecoding),
        ("testHuffmanMultiHeaderRequestDecoding", testHuffmanMultiHeaderRequestDecoding),
        ("testHeaderResponseDecoding", testHeaderResponseDecoding),
        ("testHuffmanHeaderResponseDecoding", testHuffmanHeaderResponseDecoding),
        ("testHeaderDecodingFailure0", testHeaderDecodingFailure0),
        ("testConstants", testConstants),
    ]
    
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
            let packet = Payload(data: Data([testCase]))
            
            let number = try packet.parseInteger(prefix: 5)
            
            XCTAssertEqual(number, 10)
        }
        
        let elevenPacket = Payload(data: Data([11]))
        let twelvePacket = Payload(data: Data([12]))
        
        let eleven = try elevenPacket.parseInteger(prefix: 4)
        let twelve = try twelvePacket.parseInteger(prefix: 4)
        
        XCTAssertEqual(eleven, 11)
        XCTAssertEqual(twelve, 12)
    }
    
    func testIntegerSerialization() throws {
        let message = Payload()
        try message.append(integer: 1337, prefix: 5)
        
        let leetPacket = Payload(data: Data([0b00011111, 0b10011010, 0b00001010]))
        XCTAssertEqual(message.data, leetPacket.data)
    }
    
    /// http://httpwg.org/specs/rfc7541.html#rfc.section.C.1.2
    func testMultilineHPPACKIntegers() throws {
        let leetPacket = Payload(data: Data([0b00011111, 0b10011010, 0b00001010]))
        
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
        
        let headers = try HPACKDecoder().decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers["custom-key"], "custom-header")
    }
    
    func testHeaderDecoding1() throws {
        let encodedHeaders = Data([
            0x04, 0x0c, 0x2f, 0x73, 0x61, 0x6d, 0x70,
            0x6c, 0x65, 0x2f, 0x70, 0x61, 0x74, 0x68
        ])
        
        let headers = try HPACKDecoder().decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":path"], "/sample/path")
    }
    
    func testHeaderDecoding2() throws {
        let encodedHeaders = Data([
            0x10, 0x08, 0x70, 0x61, 0x73, 0x73,
            0x77, 0x6f, 0x72, 0x64, 0x06, 0x73,
            0x65, 0x63, 0x72, 0x65, 0x74
        ])
        
        let headers = try HPACKDecoder().decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers["password"], "secret")
    }
    
    func testHeaderDecoding3() throws {
        let encodedHeaders = Data([
            0x82
        ])
        
        let headers = try HPACKDecoder().decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
    }
    
    // http://httpwg.org/specs/rfc7541.html#request.examples.without.huffman.coding
    func testPlainMultiHeaderRequestDecoding() throws {
        let decoder = HPACKDecoder()
        
        // http://httpwg.org/specs/rfc7541.html#n-first-request_1
        var encodedHeaders = Data([
            0x82, 0x86, 0x84, 0x41, 0x0f,
            0x77, 0x77, 0x77, 0x2e, 0x65,
            0x78, 0x61, 0x6d, 0x70, 0x6c,
            0x65, 0x2e, 0x63, 0x6f, 0x6d
        ])
        
        var headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 1)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, ":authority")
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "www.example.com")
        
        // http://httpwg.org/specs/rfc7541.html#n-second-request_1
        encodedHeaders = Data([
            0x82, 0x86, 0x84, 0xbe,
            0x58, 0x08, 0x6e, 0x6f,
            0x2d, 0x63, 0x61, 0x63,
            0x68, 0x65
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers[.cacheControl], "no-cache")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 2)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, "cache-control")
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, ":authority")
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "no-cache")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "www.example.com")
        
        // http://httpwg.org/specs/rfc7541.html#n-third-request_1
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
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "https")
        XCTAssertEqual(headers[":path"], "/index.html")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers["custom-key"], "custom-value")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 3)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, "custom-key")
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, "cache-control")
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, ":authority")
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "custom-value")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "no-cache")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "www.example.com")
    }
    
    // http://httpwg.org/specs/rfc7541.html#request.examples.with.huffman.coding
    func testHuffmanMultiHeaderRequestDecoding() throws {
        let decoder = HPACKDecoder()
        
        // http://httpwg.org/specs/rfc7541.html#n-first-request_2
        var encodedHeaders = Data([
            0x82, 0x86, 0x84, 0x41,
            0x8c, 0xf1, 0xe3, 0xc2,
            0xe5, 0xf2, 0x3a, 0x6b,
            0xa0, 0xab, 0x90, 0xf4,
            0xff
            ])
        
        var headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 1)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, ":authority")
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "www.example.com")
        
        // http://httpwg.org/specs/rfc7541.html#n-second-request_2
        encodedHeaders = Data([
            0x82, 0x86, 0x84, 0xbe,
            0x58, 0x86, 0xa8, 0xeb,
            0x10, 0x64, 0x9c, 0xbf
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "http")
        XCTAssertEqual(headers[":path"], "/")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers[.cacheControl], "no-cache")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 2)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, "cache-control")
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, ":authority")
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "no-cache")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "www.example.com")
        
        // http://httpwg.org/specs/rfc7541.html#n-third-request_2
        
        encodedHeaders = Data([
            0x82, 0x87, 0x85, 0xbf,
            0x40, 0x88, 0x25, 0xa8,
            0x49, 0xe9, 0x5b, 0xa9,
            0x7d, 0x7f, 0x89, 0x25,
            0xa8, 0x49, 0xe9, 0x5b,
            0xb8, 0xe8, 0xb4, 0xbf
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":method"], "GET")
        XCTAssertEqual(headers[":scheme"], "https")
        XCTAssertEqual(headers[":path"], "/index.html")
        XCTAssertEqual(headers[":authority"], "www.example.com")
        XCTAssertEqual(headers["custom-key"], "custom-value")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 3)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, "custom-key")
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, "cache-control")
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, ":authority")
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "custom-value")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "no-cache")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "www.example.com")
    }
    
    // http://httpwg.org/specs/rfc7541.html#response.examples.without.huffman.coding
    func testHeaderResponseDecoding() throws {
        let decoder = HPACKDecoder()
        decoder.tableSize = 256
        
        // http://httpwg.org/specs/rfc7541.html#n-first-response_1
        var encodedHeaders = Data([
            0x48, 0x03, 0x33, 0x30, 0x32, 0x58, 0x07, 0x70,
            0x72, 0x69, 0x76, 0x61, 0x74, 0x65, 0x61, 0x1d,
            0x4d, 0x6f, 0x6e, 0x2c, 0x20, 0x32, 0x31, 0x20,
            0x4f, 0x63, 0x74, 0x20, 0x32, 0x30, 0x31, 0x33,
            0x20, 0x32, 0x30, 0x3a, 0x31, 0x33, 0x3a, 0x32,
            0x31, 0x20, 0x47, 0x4d, 0x54, 0x6e, 0x17, 0x68,
            0x74, 0x74, 0x70, 0x73, 0x3a, 0x2f, 0x2f, 0x77,
            0x77, 0x77, 0x2e, 0x65, 0x78, 0x61, 0x6d, 0x70,
            0x6c, 0x65, 0x2e, 0x63, 0x6f, 0x6d
        ])
        
        var headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":status"], "302")
        XCTAssertEqual(headers[.cacheControl], "private")
        XCTAssertEqual(headers[.date], "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(headers[.location], "https://www.example.com")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 4)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, .location)
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, .date)
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, .cacheControl)
        XCTAssertEqual(decoder.table.dynamicEntries[3].name, ":status")
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "https://www.example.com")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "private")
        XCTAssertEqual(decoder.table.dynamicEntries[3].value, "302")
        
        encodedHeaders = Data([
            0x48, 0x03, 0x33, 0x30, 0x37, 0xc1, 0xc0, 0xbf
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":status"], "307")
        XCTAssertEqual(headers[.cacheControl], "private")
        XCTAssertEqual(headers[.date], "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(headers[.location], "https://www.example.com")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 4)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, ":status")
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, .location)
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, .date)
        XCTAssertEqual(decoder.table.dynamicEntries[3].name, .cacheControl)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "307")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "https://www.example.com")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(decoder.table.dynamicEntries[3].value, "private")
        
        encodedHeaders = Data([
            0x88, 0xc1, 0x61, 0x1d, 0x4d, 0x6f, 0x6e, 0x2c,
            0x20, 0x32, 0x31, 0x20, 0x4f, 0x63, 0x74, 0x20,
            0x32, 0x30, 0x31, 0x33, 0x20, 0x32, 0x30, 0x3a,
            0x31, 0x33, 0x3a, 0x32, 0x32, 0x20, 0x47, 0x4d,
            0x54, 0xc0, 0x5a, 0x04, 0x67, 0x7a, 0x69, 0x70,
            0x77, 0x38, 0x66, 0x6f, 0x6f, 0x3d, 0x41, 0x53,
            0x44, 0x4a, 0x4b, 0x48, 0x51, 0x4b, 0x42, 0x5a,
            0x58, 0x4f, 0x51, 0x57, 0x45, 0x4f, 0x50, 0x49,
            0x55, 0x41, 0x58, 0x51, 0x57, 0x45, 0x4f, 0x49,
            0x55, 0x3b, 0x20, 0x6d, 0x61, 0x78, 0x2d, 0x61,
            0x67, 0x65, 0x3d, 0x33, 0x36, 0x30, 0x30, 0x3b,
            0x20, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e,
            0x3d, 0x31,
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":status"], "200")
        XCTAssertEqual(headers[.cacheControl], "private")
        XCTAssertEqual(headers[.date], "Mon, 21 Oct 2013 20:13:22 GMT")
        XCTAssertEqual(headers[.location], "https://www.example.com")
        XCTAssertEqual(headers[.contentEncoding], "gzip")
        XCTAssertEqual(headers[.setCookie], "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 3)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, .setCookie)
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, .contentEncoding)
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, .date)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "gzip")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "Mon, 21 Oct 2013 20:13:22 GMT")
    }
    
    // http://httpwg.org/specs/rfc7541.html#response.examples.with.huffman.coding
    func testHuffmanHeaderResponseDecoding() throws {
        let decoder = HPACKDecoder()
        decoder.tableSize = 256
        
        var encodedHeaders = Data([
            0x48, 0x82, 0x64, 0x02, 0x58, 0x85, 0xae, 0xc3,
            0x77, 0x1a, 0x4b, 0x61, 0x96, 0xd0, 0x7a, 0xbe,
            0x94, 0x10, 0x54, 0xd4, 0x44, 0xa8, 0x20, 0x05,
            0x95, 0x04, 0x0b, 0x81, 0x66, 0xe0, 0x82, 0xa6,
            0x2d, 0x1b, 0xff, 0x6e, 0x91, 0x9d, 0x29, 0xad,
            0x17, 0x18, 0x63, 0xc7, 0x8f, 0x0b, 0x97, 0xc8,
            0xe9, 0xae, 0x82, 0xae, 0x43, 0xd3
        ])
        
        var headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":status"], "302")
        XCTAssertEqual(headers[.cacheControl], "private")
        XCTAssertEqual(headers[.date], "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(headers[.location], "https://www.example.com")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 4)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, .location)
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, .date)
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, .cacheControl)
        XCTAssertEqual(decoder.table.dynamicEntries[3].name, ":status")
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "https://www.example.com")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "private")
        XCTAssertEqual(decoder.table.dynamicEntries[3].value, "302")
        
        encodedHeaders = Data([
            0x48, 0x83, 0x64, 0x0e, 0xff, 0xc1, 0xc0, 0xbf
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":status"], "307")
        XCTAssertEqual(headers[.cacheControl], "private")
        XCTAssertEqual(headers[.date], "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(headers[.location], "https://www.example.com")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 4)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, ":status")
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, .location)
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, .date)
        XCTAssertEqual(decoder.table.dynamicEntries[3].name, .cacheControl)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "307")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "https://www.example.com")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "Mon, 21 Oct 2013 20:13:21 GMT")
        XCTAssertEqual(decoder.table.dynamicEntries[3].value, "private")
        
        encodedHeaders = Data([
            0x88, 0xc1, 0x61, 0x96, 0xd0, 0x7a, 0xbe, 0x94,
            0x10, 0x54, 0xd4, 0x44, 0xa8, 0x20, 0x05, 0x95,
            0x04, 0x0b, 0x81, 0x66, 0xe0, 0x84, 0xa6, 0x2d,
            0x1b, 0xff, 0xc0, 0x5a, 0x83, 0x9b, 0xd9, 0xab,
            0x77, 0xad, 0x94, 0xe7, 0x82, 0x1d, 0xd7, 0xf2,
            0xe6, 0xc7, 0xb3, 0x35, 0xdf, 0xdf, 0xcd, 0x5b,
            0x39, 0x60, 0xd5, 0xaf, 0x27, 0x08, 0x7f, 0x36,
            0x72, 0xc1, 0xab, 0x27, 0x0f, 0xb5, 0x29, 0x1f,
            0x95, 0x87, 0x31, 0x60, 0x65, 0xc0, 0x03, 0xed,
            0x4e, 0xe5, 0xb1, 0x06, 0x3d, 0x50, 0x07
        ])
        
        headers = try decoder.decode(Payload(data: encodedHeaders))
        
        XCTAssertEqual(headers[":status"], "200")
        XCTAssertEqual(headers[.cacheControl], "private")
        XCTAssertEqual(headers[.date], "Mon, 21 Oct 2013 20:13:22 GMT")
        XCTAssertEqual(headers[.location], "https://www.example.com")
        XCTAssertEqual(headers[.contentEncoding], "gzip")
        XCTAssertEqual(headers[.setCookie], "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1")
        
        XCTAssertEqual(decoder.table.dynamicEntries.count, 3)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].name, .setCookie)
        XCTAssertEqual(decoder.table.dynamicEntries[1].name, .contentEncoding)
        XCTAssertEqual(decoder.table.dynamicEntries[2].name, .date)
        
        XCTAssertEqual(decoder.table.dynamicEntries[0].value, "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1")
        XCTAssertEqual(decoder.table.dynamicEntries[1].value, "gzip")
        XCTAssertEqual(decoder.table.dynamicEntries[2].value, "Mon, 21 Oct 2013 20:13:22 GMT")
    }
    
    func testHeaderEncoding0() throws {
        
    }
    
    func testHeaderEncoding1() throws {
        
    }
    
    func testHeaderEncoding2() throws {
        
    }
    
    func testHeaderEncoding3() throws {
        
    }
    
    func testHeaderDecodingFailure0() throws {
        let encodedHeaders = Data([
            0x82, 0x86, 0x84, 0x41, 0x0f,
            0x77, 0x77, 0x77, 0x2e, 0x65,
            0x78, 0x61, 0x6d, 0x70, 0x6c,
            0x65, 0x2e, 0x63, 0x6f
        ])
        
        XCTAssertThrowsError(try HPACKDecoder().decode(Payload(data: encodedHeaders)))
    }
    
    func testConstants() {
        XCTAssertEqual(HeadersTable.staticEntries.count, 61)
    }
}
