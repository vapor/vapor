//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

class ValidationUniqueTests: XCTestCase {
    static let allTests = [
       ("testIntsArray", testIntsArray),
       ("testStringArray", testStringArray)
    ]

    func testIntsArray() {
        let unique = [1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(unique.passes(Unique()))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique()))
    }

    func testStringArray() {
        let unique = ["a", "b", "c", "d", "e"]
        XCTAssertTrue(unique.passes(Unique()))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique()))
    }
}

class ValidationInTests: XCTestCase {
    static let allTests = [
        ("testIntsArray", testIntsArray),
        ("testStringArray", testStringArray),
        ("testInArray", testInArray),
        ("testInSet", testInSet)
    ]

    func testIntsArray() {
        let unique = [1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(unique.passes(Unique()))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique()))
    }

    func testStringArray() {
        let unique = ["a", "b", "c", "d", "e"]
        XCTAssertTrue(unique.passes(Unique()))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique()))
    }

    func testInArray() {
        let array = [0,1,2,3]
        XCTAssertTrue(1.passes(In(array)))
        XCTAssertFalse(13.passes(In(array)))
    }

    func testInSet() throws {
        let set = Set(["a", "b", "c"])
        // Run at least two tests w/ same validator instance that should be true to 
        // ensure that iteratorFactory is functioning properly
        let validator = In(set)
        XCTAssertTrue("a".passes(validator))
        XCTAssertTrue("b".passes(validator))
        XCTAssertFalse("b".passes(!In(set)))
        XCTAssertFalse("nope".passes(validator))
    }
}
