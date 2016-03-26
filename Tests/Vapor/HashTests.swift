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
    static var allTests : [(String, HashTests -> () throws -> Void)] {
        return [
            ("testHash", testHash)
        ]
    }
    
    func testHash() {
        let app = Application()
        
        let string = "vapor"
        let expected = "97ce9a45eaf0b1ceafc3bba00dfec047526386bbd69241e4a4f0c9fde7c638ea"
        app.hash.key = "123"
        
        let result = app.hash.make(string)
        
        XCTAssert(expected == result, "Hash did not match")
        
        app.hash.key = "1234"
        
        let badResult = app.hash.make(string)
        
        XCTAssert(expected != badResult, "Hash matched bad result")
    }
    
}
