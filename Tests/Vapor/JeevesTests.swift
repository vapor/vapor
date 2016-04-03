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

class JeevesTests: XCTestCase {

    static var allTests: [(String, JeevesTests -> () throws -> Void)] {
        return [
           ("testReadRequest", testReadRequest)
        ]
    }

    func testReadRequest() throws {
        let requestLine = try HummingbirdHeader.RequestLine("POST /test?hello=world HTTP/1.1")
        let header = HummingbirdHeader(requestLine: requestLine)

        let socket = Hummingbird.Socket(socketDescriptor: 1)
        let request = try socket.makeRequest(header, body: "".data)
        XCTAssert(request.data["hello"]?.string == "world")
    }
}
