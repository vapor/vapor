//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

class Name: ValidationSuite {
    static func validate(input value: String) -> Bool {
        let evaluation = OnlyAlphanumeric.self
            + StringLength.min(5)
            + StringLength.max(20)

        return value.passes(evaluation)
    }
}


class ValidationTests: XCTestCase {
    static var allTests: [(String, ValidationTests -> () throws -> Void)] {
        return [
            ("testName", testName),
            ("testPassword", testPassword),
            ("testComposition", testComposition)
        ]
    }

    func testName() throws {
        let validName = try "fancyUser".validated(by: Name.self)
        XCTAssert(validName.value == "fancyUser")

        let failed: Validated<Name>? = try? "a*cd".validated()
        XCTAssert(failed == nil)
    }

    func testPassword() throws {
        let no = try? "no".validated(by: !OnlyAlphanumeric.self + StringLength.min(5))
        XCTAssert(no == nil)

        let yes = try? "yes*/pass".validated(by: !OnlyAlphanumeric.self + StringLength.min(5))
        XCTAssert(yes != nil)
    }

    func testComposition() throws {
        let contrived = StringLength.max(9)
            || StringLength.min(11)
            + Name.self
            + OnlyAlphanumeric.self

        let pass = try "contrive".validated(by: contrived)
        XCTAssert(pass.value == "contrive")
    }

    func testAlternateSyntax() throws {
        let _ = try Validated<Name>("Vapor")
    }
}
