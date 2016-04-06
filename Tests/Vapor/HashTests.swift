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

class HashTests: XCTestCase {
    static var allTests: [(String, HashTests -> () throws -> Void)] {
        return [
            ("testHash", testHash)
        ]
    }

    func testHash() {
        let app = Application()

        let string = "vapor"
        let expected = "01c99e8ec3c38b91c1c7a7add05044438d9aaa16"
        app.hash.key = "123"

        let result = app.hash.make(string)

        XCTAssert(expected == result, "Hash did not match")

        app.hash.key = "1234"

        let badResult = app.hash.make(string)

        XCTAssert(expected != badResult, "Hash matched bad result")
    }

}
