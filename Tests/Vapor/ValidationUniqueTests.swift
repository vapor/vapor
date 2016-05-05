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
    static var allTests: [(String, ValidationUniqueTests -> () throws -> Void)] {
        return [
            ("testIntsArray", testIntsArray),
            ("testStringArray", testStringArray)
        ]
    }

    func testIntsArray() {
        let unique = [1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(unique.passes(Unique))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique))
    }

    func testStringArray() {
        let unique = ["a", "b", "c", "d", "e"]
        XCTAssertTrue(unique.passes(Unique))
        let notUnique = unique + unique
        XCTAssertFalse(notUnique.passes(Unique))
    }
}
