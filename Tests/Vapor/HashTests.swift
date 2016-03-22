//
//  HashTests.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/22/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest
@testable import Vapor

#if os(Linux)
    extension HashTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                ("testHash", testHash)
            ]
        }
    }
#endif

class HashTests: XCTestCase {

    func testHash() {
        let string = "vapor"
        let expected = "97ce9a45eaf0b1ceafc3bba00dfec047526386bbd69241e4a4f0c9fde7c638ea"
        Hash.applicationKey = "123"

        let result = Hash.make(string)

        XCTAssert(expected == result, "Hash did not match")

        Hash.applicationKey = "1234"

        let badResult = Hash.make(string)

        XCTAssert(expected != badResult, "Hash matched bad result")
    }

}
