//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

class Name: Validator {
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
        let fail = Count<Int>.min(10)
        let pass = Count<Int>.max(30)
        let combo = pass && fail
        do {
            let _ = try 2.tested(by: combo)
            XCTFail("should throw error")
        } catch let e as ErrorList {
            XCTAssertEqual(e.errors.count, 1)
        }
    }

    func testValidEmail() {
        // Thanks again Ben Wu :)
        XCTAssertFalse("".passes(EmailValidator()))
        XCTAssertFalse("@".passes(EmailValidator()))
        XCTAssertFalse("@.".passes(EmailValidator()))
        XCTAssertFalse("@.com".passes(EmailValidator()))
        XCTAssertFalse("foo@.com".passes(EmailValidator()))
        XCTAssertFalse("@foo.com".passes(EmailValidator()))
        XCTAssertTrue("f@b.c".passes(EmailValidator()))
        XCTAssertTrue("foo@bar.com".passes(EmailValidator()))
        XCTAssertFalse("f@b.".passes(EmailValidator()))
        XCTAssertFalse("æøå@gmail.com".passes(EmailValidator()))
    }
}
