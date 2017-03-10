//
//  AcceptLanguageTests.swift
//  Vapor
//
//  Created by Hale Chan on 2016/11/11.
//
//

import XCTest
import HTTP
@testable import Vapor

class AcceptLanguageTests: XCTestCase {
    static let allTests = [
        ("testSimple", testSimple)
    ]
    
    func testSimple() throws {
        //Test case from: https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
        let request = try Request(method: .get, uri: "https://www.w3.org")
        request.headers["Accept-Language"] = "da, en-gb;q=0.8, en;q=0.7"
        
        let array = request.acceptLanguage
        
        XCTAssert(3 == array.count)
        
        let da = array[0]
        XCTAssert(da.languageRange == "da" && da.quality == 1.0)
        
        let enGb = array[1]
        XCTAssert(enGb.languageRange == "en-gb" && enGb.quality == 0.8)
        
        let en = array[2]
        XCTAssert(en.languageRange == "en" && en.quality == 0.7)
    }
}
