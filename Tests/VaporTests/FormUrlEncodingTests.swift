import XCTest
import Core
@testable import Vapor

class FormUrlEncodingTests: XCTestCase {
    static let allTests = [
        ("testFormUrlEncoded", testFormUrlEncoded)
    ]

//    func testFormUrlEncoded() throws {
//        let r = TestRenderer(viewsDir: "ferret")
//        r.views["foo"] = "42".makeBytes()
//
//        let view = try r.make("foo")
//        XCTAssertEqual(view.data.makeString(), "42")
//
//
//        let view2 = try r.make("foo", "context")
//        XCTAssertEqual(view2.data.makeString(), "42")
//    }
    
    
    func testFormUrlEncoded() throws{
        let expectation = try formURLEncode(Node(node: [
            "testphrase": "M53Tx+pvFIaujZ/\\jKxEcJFg==&"
            ]))
        
        
        // what it should be
        // what it actually is
        let result = try Node(node: [
            "testphrase": "M53Tx+pvFIaujZ/\\jKxEcJFg==&"
            ]).formURLEncoded()
        
        // check if 'what it is' == 'what it should be'
        XCTAssertEqual(expectation, result)
    }
    
    
    
    func formURLEncode(_ node:Node) throws -> Bytes {
        guard let dict = node.object else { return [] }
        
        var bytes: [[Byte]] = []
        
        for (key, val) in dict {
            var subbytes: [Byte] = []
            subbytes += try percentEncoded(key.bytes)
            subbytes += Byte.equals
            subbytes += try percentEncoded(val.string?.bytes ?? [])
            bytes.append(subbytes)
        }
        
        return bytes.joined(separator: [Byte.ampersand]).array
    }
    
    
    func percentEncoded(
        _ input: [Byte],
        shouldEncode: (Byte) throws -> Bool = { _ in true }
        ) throws -> [Byte] {
        var group: [Byte] = []
        try input.forEach { byte in
            if try shouldEncode(byte) {
                let hex = String(byte, radix: 16).utf8
                group.append(.percent)
                if hex.count == 1 {
                    group.append(.zero)
                }
                group.append(contentsOf: hex)
            } else {
                group.append(byte)
            }
        }
        return group
    }
    
    

  }
