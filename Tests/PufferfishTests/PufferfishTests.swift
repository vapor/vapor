import XCTest
import Foundation
@testable import Pufferfish

public class PufferfishTests: XCTestCase {
    static let allTests = [
        ("testEncoding", testEncoding),
        ("testDecoding", testDecoding),
        ("testReencode", testReencode),
        ("testRedecode", testRedecode),
    ]
    
    let tree = HuffmanTree(
        left: .tree(HuffmanTree(
            left: .leaf(.single(0xff)),
            right: .leaf(.single(0xf0))
        )),
        right: .tree(HuffmanTree(
            left: .leaf(.single(0x00)),
            right: .leaf(.single(0x0f))
        ))
    )
    
    let preencoded = Data([
        0b10010011,
        0b10010011,
        0b00000000,
        0b11111111,
        0b01010101,
        0b10101010
    ])
    
    let predecoded = Data([
        0x00, 0xf0, 0xff, 0x0f,
        0x00, 0xf0, 0xff, 0x0f,
        0xff, 0xff, 0xff, 0xff,
        0x0f, 0x0f, 0x0f, 0x0f,
        0xf0, 0xf0, 0xf0, 0xf0,
        0x00, 0x00, 0x00, 0x00
    ])
    
    func testEncoding() throws {
        let encoder = HuffmanEncoder(encodingTable: tree.encodingTable)
        let encoded = try encoder.encode(data: predecoded)
        
        XCTAssertEqual(encoded, preencoded)
    }
    
    func testDecoding() throws {
        let decoder = HuffmanDecoder(tree: tree)
        let decoded = decoder.decode(data: preencoded)
        
        XCTAssertEqual(predecoded, decoded)
    }
    
    func testReencode() throws {
        let decoder = HuffmanDecoder(tree: tree)
        let decoded = decoder.decode(data: preencoded)
        
        let encoded = try HuffmanEncoder(encodingTable: tree.encodingTable).encode(data: decoded)
        
        XCTAssertEqual(encoded, preencoded)
    }
    
    func testRedecode() throws {
        let encoded = try HuffmanEncoder(encodingTable: tree.encodingTable).encode(data: predecoded)
        
        let decoder = HuffmanDecoder(tree: tree)
        let decoded = decoder.decode(data: encoded)
        
        XCTAssertEqual(decoded, predecoded)
    }
}
