import XCTest
import Bits
@testable import Random

class RandomTests: XCTestCase {
    static var allTests = [
        ("testURandom", testURandom),
        ("testOSRandom", testOSRandom),
        ("testURandomCount", testURandomCount),
        ("testForTrailingZeros", testForTrailingZeros)
    ]

    func testURandom() throws {
        let rand = try URandom.makeInt8()
        print(rand)
    }

    func testOSRandom() throws {
        let rand = try OSRandom.makeInt64()
        print(rand)
        let bytes = try OSRandom.bytes(count: 32)
        print(String(data: bytes, encoding: .utf8) ?? "n/a")
    }

    func testURandomCount() throws {
        let rand = try URandom.bytes(count: 65_536)
        XCTAssertEqual(rand.count, 65_536)
    }

    func testForTrailingZeros() throws {
        let rand = try URandom.bytes(count: 65_536)
        let tail = Bytes(rand.suffix(8))
        let zeros = Bytes(repeating: 0, count: 8)
        XCTAssertNotEqual(tail, zeros)
    }
    
    func testArray() throws {
        let array = [1, 2, 3]
        var results: [Int: Int] = [:]
        for _ in 0..<65_536 {
            if let foo = array.random {
                results[foo] = (results[foo] ?? 0) + 1
            }
        }
        print(results)
    }
}
