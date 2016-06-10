import Foundation
import XCTest
@testable import Vapor


class UtilityTests: XCTestCase {

    static var allTests: [(String, (UtilityTests) -> () throws -> Void)] {
        return [
            ("testLowercase", testLowercase),
        ]
    }

    func testLowercase() {
        let test = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()"

        XCTAssertEqual(
            test.data.lowercased.string,
            test.lowercased(),
            "Data utility did not match Foundation"
        )
    }

    func testUppercase() {
        let test = "abcdefghijklmnopqrstuvwxyz1234567890!@#$%^&*()"

        XCTAssertEqual(
            test.data.uppercased.string,
            test.uppercased(),
            "Data utility did not match Foundation"
        )
    }
    
}
