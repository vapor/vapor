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
            ("testMultipart", testMultipart),
            ("testMultipartFile", testMultipartFile),
            ("testFormURLEncoded", testFormURLEncoded),
            ("testFormURLEncodedEdge", testFormURLEncodedEdge),
            ("testSplitString", testSplitString)
        ]
    }

    func testParse() {
        let request = Request(
            method: .post,
            path: "/",
            headers: [
                "content-type": "application/x-www-form-urlencoded"
            ],
            data: "value=123".data
        )

        XCTAssert(request.data["value"].int == 123, "Request did not parse correctly")
    }

    func testMultipart() {
        let boundary = "~~vapor~~"

        var body = "--" + boundary + "\r\n"
        body += "Content-Disposition: form-data; name=\"value\"\r\n"
        body += "\r\n"
        body += "123\r\n"
        body += "--" + boundary + "\r\n"

        let request = Request(
            method: .post,
            path: "/",
            headers: [
                "content-type": "multipart/form-data; charset=utf-8; boundary=\(boundary)"
            ],
            data: body.data
        )

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

        let request = Request(
            method: .post,
            path: "/",
            headers: [
                "content-type": "multipart/form-data; charset=utf-8; boundary=\(boundary)"
            ],
            data: body.data
        )

        XCTAssert(request.data.multipart?["value"]?.file?.data == "123".data, "Request did not parse correctly")
    }

    func testFormURLEncoded() {
        let body = "first=value&arr[]=foo+bar&arr[]=baz"
        let request = Request(
            method: .post,
            path: "/",
            headers: [
                "content-type": "application/x-www-form-urlencoded"
            ],
            data: body.data
        )

        XCTAssert(request.data["first"].string == "value", "Request key first did not parse correctly")
        XCTAssert(request.data["arr", 0].string == "foo bar", "Request key arr did not parse correctly")
        XCTAssert(request.data["arr", 1].string == "baz", "Request key arr did not parse correctly")
    }

    func testFormURLEncodedEdge() {
        let body = "singleKeyArray[]=value&implicitArray=1&implicitArray=2"
        let request = Request(
            method: .post,
            path: "/",
            headers: [
                "content-type": "application/x-www-form-urlencoded"
            ],
            data: body.data
        )

        XCTAssert(request.data["singleKeyArray", 0].string == "value", "singleKeyArray did not parse correctly")
        XCTAssert(request.data["implicitArray", 0].string == "1", "implicitArray did not parse correctly")
        XCTAssert(request.data["implicitArray", 1].string == "2", "implicitArray did not parse correctly")
    }

    func testSplitString() {
        let input = "multipart/form-data; boundary=----WebKitFormBoundaryAzXMX6nUkSI9kQbq"
        let val = input.components(separatedBy: "boundary=")
        print("succeeded w/ \(val) because didn't crash")
    }
}
