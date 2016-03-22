//
//  JeevesTests.swift
//  Vapor
//
//  Created by Logan Wright on 3/12/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest

@testable import Vapor

private final class TestSocket: Socket {

    private let id: String = NSUUID().UUIDString

    var testRequestBytes: [Byte] =  [80, 79, 83, 84, 32, 47, 116, 101, 115, 116, 32, 72, 84, 84, 80, 47, 49, 46, 49, 13, 10, 67, 117, 115, 116, 111, 109, 75, 101, 121, 58, 32, 67, 117, 115, 116, 111, 109, 86, 97, 108, 32, 58, 33, 42, 38, 13, 10, 67, 111, 110, 116, 101, 110, 116, 45, 84, 121, 112, 101, 58, 32, 97, 112, 112, 108, 105, 99, 97, 116, 105, 111, 110, 47, 106, 115, 111, 110, 13, 10, 72, 111, 115, 116, 58, 32, 108, 111, 99, 97, 108, 104, 111, 115, 116, 58, 56, 48, 56, 48, 13, 10, 67, 111, 110, 110, 101, 99, 116, 105, 111, 110, 58, 32, 99, 108, 111, 115, 101, 13, 10, 85, 115, 101, 114, 45, 65, 103, 101, 110, 116, 58, 32, 80, 97, 119, 47, 50, 46, 50, 46, 57, 32, 40, 77, 97, 99, 105, 110, 116, 111, 115, 104, 59, 32, 79, 83, 32, 88, 47, 49, 48, 46, 49, 49, 46, 51, 41, 32, 71, 67, 68, 72, 84, 84, 80, 82, 101, 113, 117, 101, 115, 116, 13, 10, 67, 111, 110, 116, 101, 110, 116, 45, 76, 101, 110, 103, 116, 104, 58, 32, 49, 55, 13, 10, 13, 10, 123, 34, 104, 101, 108, 108, 111, 34, 58, 34, 119, 111, 114, 108, 100, 34, 125]


    func read(bufferLength: Int) throws -> [Byte] {
        let prefix = testRequestBytes.prefix(bufferLength)
        let suffix = testRequestBytes.suffixFrom(bufferLength)
        testRequestBytes = [Byte](suffix)
        return [Byte](prefix)
    }

    func write(buffer: [Byte]) throws {
        fatalError("Not yet supported")
    }

    func bind(toAddress address: String?, onPort port: String?) throws {
        fatalError("Not yet supported")
    }

    private func listen(pendingConnectionBacklog backlog: Int) throws {
        fatalError("Not yet supported")
    }

    private func accept(maximumConsecutiveFailures: Int, connectionHandler: (TestSocket) -> Void) throws {
        fatalError("Not yet supported")
    }

    func close() throws {
        fatalError("Not yet supported")
    }

    private static func makeSocket() throws -> TestSocket {
        return self.init()
    }
}


#if os(Linux)
    extension JeevesTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                       ("testReadHeader", testReadHeader),
                       ("testReadRequest", testReadRequest)
            ]
        }
    }
#endif

class JeevesTests: XCTestCase {

    func testReadHeader() throws {
        let socket = TestSocket()
        let header = try Request.Header(socket)

        let requestLine = header.requestLine
        XCTAssert(requestLine.method == "POST")
        XCTAssert(requestLine.uri == "/test")
        XCTAssert(requestLine.version == "HTTP/1.1")

        let fields = header.fields
        XCTAssert(fields["Content-Length"] == "17")
        XCTAssert(fields["Content-Type"] == "application/json")
        XCTAssert(fields["CustomKey"] == "CustomVal :!*&")
        XCTAssert(fields["User-Agent"] == "Paw/2.2.9 (Macintosh; OS X/10.11.3) GCDHTTPRequest")
        XCTAssert(fields["Connection"] == "close")
        XCTAssert(fields["Host"] == "localhost:8080")
    }

    func testReadRequest() throws {
        let socket = TestSocket()
        let request = try socket.readRequest()
        XCTAssert(request.data["hello"]?.string == "world")
    }
}
