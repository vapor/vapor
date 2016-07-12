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
        XCTAssertTrue(unique.passes(Unique.self))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique.self))
    }

    func testStringArray() {
        let unique = ["a", "b", "c", "d", "e"]
        XCTAssertTrue(unique.passes(Unique.self))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique.self))
    }
}

class ValidationInTests: XCTestCase {
    static var allTests: [(String, (ValidationInTests) -> () throws -> Void)] {
        return [
                   ("testIntsArray", testIntsArray),
                   ("testStringArray", testStringArray)
        ]
    }

    func testIntsArray() {
        let unique = [1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(unique.passes(Unique.self))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique.self))
    }

    func testStringArray() {
        let unique = ["a", "b", "c", "d", "e"]
        XCTAssertTrue(unique.passes(Unique.self))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique.self))
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

    func testGenerator() {
        let array = [0.0, 1.0, 2.0, 3.0]
        var idx = 0
        let generator = AnyIterator<Double> {
            guard idx < array.count else {
                XCTFail("Generator should stop when equality found")
                return nil
            }
            let next = array[idx] // will crash if exceeds, we're testing that
            idx += 1
            return next
        }

        XCTAssertTrue(3.0.passes(In(generator)))
    }
}
