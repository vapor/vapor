import XCTest
@testable import HTTP2

public class ParsingTests: XCTestCase {
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
}
