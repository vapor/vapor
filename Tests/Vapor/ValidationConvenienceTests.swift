//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

class ValidationConvenienceTests: XCTestCase {
    static let allTests = [
       ("testTrue", testTrue),
       ("testFalse", testFalse)
    ]

    func testTrue() throws {
    }

    func testFalse() throws {
    }
}

class AlphanumericValidationTests: ValidationConvenienceTests {
    override func testTrue() throws {
        let alphanumeric = "Analphanumericstring"
        let _ = try alphanumeric.tested(by: OnlyAlphanumeric.self)
    }

    override func testFalse() throws {
        let not = "I've got all types of characters!"
        XCTAssertFalse(not.passes(OnlyAlphanumeric.self))
    }
}

class CompareValidationTests: ValidationConvenienceTests {
    override func testTrue() throws {
        let comparable = 2.3
        let _ = try comparable.tested(by: Compare.lessThan(5.0))
        let _ = try comparable.tested(by: Compare.equals(2.3))
        let _ = try comparable.tested(by: Compare.greaterThan(1.0))

        let a = "a"
        let _ = try a.tested(by: Compare.lessThan("z") && Count.equals(1) && OnlyAlphanumeric.self)
    }

    override func testFalse() throws {
        let comparable = 42.0

        XCTAssertFalse(comparable.passes(Compare.greaterThan(50)))
        XCTAssertFalse(comparable.passes(Compare.equals(-1)))
        XCTAssertFalse(comparable.passes(Compare.lessThan(1)))

        let a = "z"
        XCTAssertFalse(a.passes(Compare.lessThan("d")))
        XCTAssertFalse(a.passes(Count.equals(10)))
        XCTAssertFalse(a.passes(!OnlyAlphanumeric.self))
    }
}

class ContainsValidationTests: ValidationConvenienceTests {
    override func testTrue() throws {
        let collection = [1, 2, 3, 4, 5]
        let _ = try collection.tested(by: Contains(1))
        let _ = try collection.tested(by: Contains(2))
        let _ = try collection.tested(by: Contains(3))
    }

    override func testFalse() throws {
        let collection = ["a", "b", "c", "d"]
        let _ = try collection.tested(by: Contains("a"))
        let _ = try collection.tested(by: Contains("b"))
        let _ = try collection.tested(by: Contains("c"))
    }
}
