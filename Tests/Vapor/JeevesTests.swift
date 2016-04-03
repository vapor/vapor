//
//  JeevesTests.swift
//  Vapor
//
//  Created by Logan Wright on 3/12/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest

@testable import Hummingbird
@testable import Vapor
@testable import C7

private final class TestSocket {
    static var testRequestBytes: Data =  [80, 79, 83, 84, 32, 47, 116, 101, 115, 116, 32, 72, 84, 84, 80, 47, 49, 46, 49, 13, 10, 67, 117, 115, 116, 111, 109, 75, 101, 121, 58, 32, 67, 117, 115, 116, 111, 109, 86, 97, 108, 32, 58, 33, 42, 38, 13, 10, 67, 111, 110, 116, 101, 110, 116, 45, 84, 121, 112, 101, 58, 32, 97, 112, 112, 108, 105, 99, 97, 116, 105, 111, 110, 47, 106, 115, 111, 110, 13, 10, 72, 111, 115, 116, 58, 32, 108, 111, 99, 97, 108, 104, 111, 115, 116, 58, 56, 48, 56, 48, 13, 10, 67, 111, 110, 110, 101, 99, 116, 105, 111, 110, 58, 32, 99, 108, 111, 115, 101, 13, 10, 85, 115, 101, 114, 45, 65, 103, 101, 110, 116, 58, 32, 80, 97, 119, 47, 50, 46, 50, 46, 57, 32, 40, 77, 97, 99, 105, 110, 116, 111, 115, 104, 59, 32, 79, 83, 32, 88, 47, 49, 48, 46, 49, 49, 46, 51, 41, 32, 71, 67, 68, 72, 84, 84, 80, 82, 101, 113, 117, 101, 115, 116, 13, 10, 67, 111, 110, 116, 101, 110, 116, 45, 76, 101, 110, 103, 116, 104, 58, 32, 49, 55, 13, 10, 13, 10, 123, 34, 104, 101, 108, 108, 111, 34, 58, 34, 119, 111, 114, 108, 100, 34, 125]

}

class JeevesTests: XCTestCase {

    static var allTests: [(String, JeevesTests -> () throws -> Void)] {
        return [
           ("testReadRequest", testReadRequest)
        ]
    }

    func testReadRequest() throws {
        let requestLine = try HummingbirdHeader.RequestLine("GET * HTTP/1.1")
        let header = HummingbirdHeader(requestLine: requestLine)

        let socket = Hummingbird.Socket(socketDescriptor: 1)
        let request = try socket.makeRequest(header, body: TestSocket.testRequestBytes)
        XCTAssert(request.data["hello"]?.string == "world")
    }
}
