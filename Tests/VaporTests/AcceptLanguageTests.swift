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
        ("testSimple", testSimple),
        ("testComplex", testComplex)
    ]
    
    func testSimple() throws {
        //Test case from: https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
        let request = Request(method: .get, uri: "https://www.w3.org")
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
    
    func testComplex() throws {
        let req = Request(method: .get, uri: "https://vapor.codes")
        req.headers[.acceptLanguage] = "zh-CN,zh;q=0.8,en-US;q=0.6,en;q=0.4"
        
        XCTAssertEqual(req.acceptLanguage.count, 4)
        XCTAssertEqual(req.acceptLanguage.first?.languageRange, "zh-CN")
    }
}
