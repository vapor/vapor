import XCTest
@testable import Vapor

class DataSplitTests: XCTestCase {
    static let allTests = [
        ("testSplitLargeFiles", testSplitLargeFiles)
    ]

    func testSplitLargeFiles() {
        let setZero = Bytes(repeating: 0, count: 1000)
        let setOne = Bytes(repeating: 1, count: 4000)
        let group = setZero + setOne // 5kb
        let count = 60 // 60 * 5 == 300 which is breaking test case
        let largeByteArray = [Bytes](repeating: group, count: count).flatMap { $0 }
        let split = largeByteArray.split(separator: setZero, excludingFirst: true) //, excludingLast: <#T##Bool#>, maxSplits: <#T##Int?#>)
        XCTAssert(split.count == count)
    }
}
