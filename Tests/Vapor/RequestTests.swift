//
//  Response.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/3/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class RequestTests: XCTestCase {
    static var allTests: [(String, (RequestTests) -> () throws -> Void)] {
        return [
            ("testParse", testParse),
            ("testCachedParse", testCachedParse),
            ("testMultipart", testMultipart),
            ("testMultipartFile", testMultipartFile)
        ]
    }

    func testParse() {
        let string = "value=123"
        let request = Request(method: .post, path: "/", host: nil, body: string.data)

        XCTAssert(request.data["value"].int == 123, "Request did not parse correctly")
    }

    func testCachedParse() {
        let string = "value=123"
        var request = Request(method: .post, path: "/", host: nil, body: string.data)
        request.parseData()

        XCTAssert(request.data["value"].int == 123, "Request did not parse correctly")
    }

    func testMultipart() {
        let boundary = "~~vapor~~"

        var body = "--" + boundary + "\r\n"
        body += "Content-Disposition: form-data; name=\"value\"\r\n"
        body += "\r\n"
        body += "123\r\n"
        body += "--" + boundary + "\r\n"

        var request = Request(method: .post, path: "/", host: nil, body: body.data)
        request.headers.headers["content-type"] = Request.Header("multipart/form-data; charset=utf-8; boundary=\(boundary)")

        request.parseData()

        XCTAssert(request.data["value"].int == 123, "Request did not parse correctly")
    }

    func testMultipartFile() {
        let boundary = "~~vapor~~"

        var body = "--" + boundary + "\r\n"
        body += "Content-Disposition: form-data; name=\"value\"\r\n"
        body += "Content-Type: image/gif\r\n"
        body += "\r\n"
        body += "123"
        body += "--" + boundary + "\r\n"

        var request = Request(method: .post, path: "/", host: nil, body: body.data)
        request.headers.headers["content-type"] = Request.Header("multipart/form-data; charset=utf-8; boundary=\(boundary)")

        request.parseData()

        XCTAssert(request.data.multipart?["value"]?.file?.data == "123".data, "Request did not parse correctly")
    }
}
