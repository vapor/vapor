import XCTest
import Crypto

class Base64Tests : XCTestCase {
    static var allTests = [
        ("testEncoding", testEncoding)
    ]
    
    func encMatch(_ string: String, toMatch match: String) throws {
        let result = try Base64Encoder.encode(string: string)
        
        XCTAssertEqual(result, match)
    }
    
    func testEncoding() throws {
        try encMatch("t", toMatch: "dA==")
        try encMatch("te", toMatch: "dGU=")
        try encMatch("tes", toMatch: "dGVz")
        try encMatch("test", toMatch: "dGVzdA==")
        try encMatch("test1", toMatch: "dGVzdDE=")
    }
}
