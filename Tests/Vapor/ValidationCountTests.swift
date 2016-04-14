//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

extension Node {
    public func validated<T: Validator where T.InputType == String>(by validator: T) throws -> Validated<T> {
        guard let string = self.string else {
            throw Failure<String>(input: nil)
        }

        return try string.validated(by: validator)
    }
}

class ValidationCountTests: XCTestCase {
    static var allTests: [(String, ValidationCountTests -> () throws -> Void)] {
        return [
            ("testCountString", testCountString),
            ("testCountInteger", testCountInteger),
            ("testCountArray", testCountArray)
        ]
    }

    func testCountString() {
        let string = "123456789"
        XCTAssertTrue(string.passes(Count.equals(9)))
        XCTAssertTrue(string.passes(Count.containedIn(low: 8, high: 10)))

        XCTAssertTrue(string.passes(!Count.equals(1)))

        XCTAssertFalse(string.passes(Count.min(10)))
        XCTAssertFalse(string.passes(Count.max(8)))
    }

    func testCountInteger() {
        let value = 231
        XCTAssertTrue(value.passes(Count.equals(231)))
        XCTAssertTrue(value.passes(!Count.containedIn(low: 0, high: 100)))

        XCTAssertFalse(value.passes(!Count.equals(231)))

        XCTAssertFalse(value.passes(Count.min(300)))
        XCTAssertFalse(value.passes(Count.max(200)))
    }

    func testCountArray() {
        let array = [1,2,3,4,5]
        XCTAssertTrue(array.passes(Count.equals(5)))
        XCTAssertTrue(array.passes(Count.containedIn(low: 0, high: 10)))

        XCTAssertTrue(array.passes(!Count.equals(0)))

        XCTAssertFalse(array.passes(Count.min(10)))
        XCTAssertFalse(array.passes(Count.max(1)))
    }
}
