//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

class Name: _Validator {
    func validate(_ input: String) throws {
        let evaluation = OnlyAlphanumeric()
            && Count.min(5)
            && Count.max(20)

        try evaluation.validate(input)
    }
}


class ValidationTests: XCTestCase {
    static let allTests = [
        ("testName", testName),
        ("testPassword", testPassword),
        ("testNot", testNot),
        ("testComposition", testComposition),
    ]

    func testName() throws {
        try "fancyUser".validated(by: Name())
        try Name().validate("fancyUser")
    }

    func testPassword() throws {
        do {
            try "no".validated(by: !OnlyAlphanumeric() && Count.min(5))
            XCTFail("Should error")
        } catch {}

        try "yes*/pass".validated(by: !OnlyAlphanumeric() && Count.min(5))
    }

    func testNot() {
        XCTAssertFalse("a".passes(!OnlyAlphanumeric()))
    }

    func testComposition() throws {
        let contrived = Count.max(9)
            || Count.min(11)
            && Name()
            && OnlyAlphanumeric()

        try "contrive".validated(by: contrived)
    }

    func testDetailedFailure() throws {
        XCTFail("fixme")
//        let fail = Count<Int>.min(10)
//        let pass = Count<Int>.max(30)
//        let combo = pass && fail
//        do {
//            let _ = try 2.tested(by: combo)
//            XCTFail("should throw error")
//        } catch let e as ValidationError<Count<Int>> {
//            XCTAssertNotNil(e.validator)
//            XCTAssertNotNil(e.input == 2)
//        }
    }

    func testValidEmail() {
        // Thanks again Ben Wu :)
        XCTAssertFalse("".passes(Email()))
        XCTAssertFalse("@".passes(Email()))
        XCTAssertFalse("@.".passes(Email()))
        XCTAssertFalse("@.com".passes(Email()))
        XCTAssertFalse("foo@.com".passes(Email()))
        XCTAssertFalse("@foo.com".passes(Email()))
        XCTAssertTrue("f@b.c".passes(Email()))
        XCTAssertTrue("foo@bar.com".passes(Email()))
        XCTAssertFalse("f@b.".passes(Email()))
        XCTAssertFalse("æøå@gmail.com".passes(Email()))
    }
}
