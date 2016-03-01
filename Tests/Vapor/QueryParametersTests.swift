//
//  QueryParametersTests.swift
//  Vapor
//
//  Created by Logan Wright on 2/28/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

@testable import Vapor

#if os(Linux)
    extension QueryParameterTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                       ("testArgumentExtraction", testArgumentExtraction)
            ]
        }
    }
#endif

class QueryParameterTests: XCTestCase {
    
    func testArgumentExtraction() {
        let url = "https://www.example.com/users?name=test&inclusiveQuestionMark=a?b&inclusiveEquals=a=b"
        let query = url.queryData()
        
        XCTAssert(query["name"] == "test")
        XCTAssert(query["inclusiveQuestionMark"] == "a?b")
        XCTAssert(query["inclusiveEquals"] == "a=b")
    }
}
