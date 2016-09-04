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
    static func validate(input value: String) throws {
        let evaluation = OnlyAlphanumeric.self
            && Count.min(5)
            && Count.max(20)

        try evaluation.validate(input: value)
    }
}


class ValidationTests: XCTestCase {
    static let allTests = [
        ("testName", testName),
        ("testPassword", testPassword),
        ("testNot", testNot),
        ("testComposition", testComposition),
        ("testAlternateSyntax", testAlternateSyntax)
    ]

    func testName() throws {
        let validName = try "fancyUser".validated(by: Name.self)
        XCTAssert(validName.value == "fancyUser")

        let failed: Valid<Name>? = try? "a*cd".validated()
        XCTAssert(failed == nil)
    }

    func testPassword() throws {
        let no = try? "no".validated(by: !OnlyAlphanumeric.self && Count.min(5))
        XCTAssert(no == nil)

        let yes = try? "yes*/pass".validated(by: !OnlyAlphanumeric.self && Count.min(5))
        XCTAssert(yes != nil)
    }

    func testNot() throws {
        let a = try? "a".validated(by: !OnlyAlphanumeric.self)
        XCTAssertNil(a)
    }

    func testComposition() throws {
        let contrived = Count.max(9)
            || Count.min(11)
            && Name.self
            && OnlyAlphanumeric.self

        let pass = try "contrive".validated(by: contrived)
        XCTAssert(pass.value == "contrive")
    }

    func testAlternateSyntax() throws {
        let _ = try Valid<Name>("Vapor")
    }

    func testDetailedFailure() throws {
        let fail = Count<Int>.min(10)
        let pass = Count<Int>.max(30)
        let combo = pass && fail
        do {
            let _ = try 2.tested(by: combo)
            XCTFail("should throw error")
        } catch let e as ValidationError<Count<Int>> {
            XCTAssertNotNil(e.validator)
            XCTAssertNotNil(e.input == 2)
        }
    }

    func testValidEmail() {
        // Thanks again Ben Wu :)
        XCTAssertFalse("".passes(Email.self))
        XCTAssertFalse("@".passes(Email.self))
        XCTAssertFalse("@.".passes(Email.self))
        XCTAssertFalse("@.com".passes(Email.self))
        XCTAssertFalse("foo@.com".passes(Email.self))
        XCTAssertFalse("@foo.com".passes(Email.self))
        XCTAssertTrue("f@b.c".passes(Email.self))
        XCTAssertTrue("foo@bar.com".passes(Email.self))
        XCTAssertFalse("f@b.".passes(Email.self))
        XCTAssertFalse("æøå@gmail.com".passes(Email.self))
    }
}
