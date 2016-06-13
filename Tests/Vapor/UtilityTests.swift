import Foundation
import XCTest
@testable import Vapor


class UtilityTests: XCTestCase {

    static var allTests = [
        ("testLowercase", testLowercase),
        ("testUppercase", testUppercase),
        ("testDecimalInt", testDecimalInt),
        ("testDecimalIntError", testDecimalIntError),
    ]

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

    func testDecimalInt() {
        let test = "1337"
        XCTAssertEqual(test.bytes.decimalInt, 1337)
    }

    func testDecimalIntError() {
        let test = "13ferret37"
        XCTAssertEqual(test.bytes.decimalInt, nil)
    }
}
