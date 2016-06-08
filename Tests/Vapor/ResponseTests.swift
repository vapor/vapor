//
//  Response.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/3/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class ResponseTests: XCTestCase {
    static var allTests: [(String, (ResponseTests) -> () throws -> Void)] {
        return [
           ("testRedirect", testRedirect),
           ("testCookiesSerialization", testCookiesSerialization)
        ]
    }

    func testRedirect() {
        let url = "http://tanner.xyz"

        let redirect = Response(redirect: url)
        XCTAssert(redirect.headers["location"] == url, "Location header should be in headers")
    }

    func testCookiesSerialization() {
        var cookies: Cookies = []
        cookies["key"] = "val"

        let data = cookies.serialize()

        let expected = "key=val"
        XCTAssert(data == expected.data, "Cookies did not serialize")
    }

}
