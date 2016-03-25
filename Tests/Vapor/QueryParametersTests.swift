//
//  QueryParametersTests.swift
//  Vapor
//
//  Created by Logan Wright on 2/28/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

@testable import Vapor

class QueryParameterTests: XCTestCase {
    static var allTests : [(String, QueryParameterTests -> () throws -> Void)] {
        return [
           ("testArgumentExtraction", testArgumentExtraction)
        ]
    }
    
    func testArgumentExtraction() {
        let url = "https://www.example.com/users?name=test&inclusiveQuestionMark=a?b&inclusiveEquals=a=b"
        let query = url.queryData()
        
        XCTAssert(query["name"] == "test")
        XCTAssert(query["inclusiveQuestionMark"] == "a?b")
        XCTAssert(query["inclusiveEquals"] == "a=b")
    }
}
