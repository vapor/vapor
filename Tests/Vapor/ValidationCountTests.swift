//
//  EventTests.swift
//  Vapor
//
//  Created by Logan Wright on 4/6/16.
//
//

import XCTest
@testable import Vapor

class ValidationCountTests: XCTestCase {
    static let allTests = [
        ("testCountString", testCountString),
        ("testCountInteger", testCountInteger),
        ("testCountArray", testCountArray)
    ]

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
        let array = [1, 2, 3, 4, 5]
        XCTAssertTrue(array.passes(Count.equals(5)))
        XCTAssertTrue(array.passes(Count.containedIn(low: 0, high: 10)))

        XCTAssertTrue(array.passes(!Count.equals(0)))

        XCTAssertFalse(array.passes(Count.min(10)))
        XCTAssertFalse(array.passes(Count.max(1)))
    }
}
