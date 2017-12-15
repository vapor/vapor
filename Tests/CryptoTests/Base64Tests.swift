import XCTest
import Async
import Bits
import Crypto

class Base64Tests: XCTestCase {
    func encMatch(_ string: String, toMatch match: String) throws {
        let result = Base64Encoder().encode(string: string)
        
        XCTAssertEqual(result, match)
        
        let old = try Base64Decoder().decode(string: result)
        
        XCTAssertEqual(string, String(bytes: old, encoding: .utf8))
    }
    
    func testStreaminingEncoding() throws {
        let input = EmitterStream<ByteBuffer>()
        var buffer = ""
        
        let encoderStream = Base64Encoder(bufferCapacity: 100).stream()

        var upstream: ConnectionContext?
        input.stream(to: encoderStream).drain { req in
            upstream = req
            req.request()
        }.output { bytes in
            buffer += String(bytes: bytes, encoding: .utf8)!
            upstream!.request()
        }.catch { err in
            XCTFail("\(err)")
        }.finally {
            // done
        }
        
        Data("tes".utf8).withUnsafeBytes { (pointer: BytesPointer) in
            input.emit(ByteBuffer(start: pointer, count: 1))
            input.emit(ByteBuffer(start: pointer.advanced(by: 1), count: 2))
        }
        
        Data("t1".utf8).withUnsafeBytes { (pointer: BytesPointer) in
            input.emit(ByteBuffer(start: pointer, count: 1))
            input.emit(ByteBuffer(start: pointer.advanced(by: 1), count: 1))
        }
        
        input.close()
        
        XCTAssertEqual(buffer, "dGVzdDE=")
    }
    
    func testEncoding() throws {
        try encMatch("t", toMatch: "dA==")
        try encMatch("te", toMatch: "dGU=")
        try encMatch("tes", toMatch: "dGVz")
        try encMatch("test", toMatch: "dGVzdA==")
        try encMatch("test1", toMatch: "dGVzdDE=")
    }

    static var allTests = [
        ("testEncoding", testEncoding)
    ]
}
