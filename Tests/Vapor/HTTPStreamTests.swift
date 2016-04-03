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
@testable import C7

final class TestHTTPStream: HTTPStream {
    enum Error: ErrorProtocol {
        case Closed
    }

    var buffer: Data
    init() {
        let content = "{\"hello\": \"world\"}"

        var request = "POST /json HTTP/1.1\r\n"
        request += "Accept-Encoding: gzip, deflate\r\n"
        request += "Accept: */*\r\n"
        request += "Accept-Language: en-us\r\n"
        request += "Content-Type: application/json\r\n"
        request += "Content-Length: \(content.characters.count)\r\n"
        request += "\r\n"
        request += content

        buffer = request.data
    }

    static func makeStream() -> TestHTTPStream {
        return TestHTTPStream()
    }

    func accept(max connectionCount: Int, handler: (HTTPStream -> Void)) throws {

    }

    func bind(to ip: String?, on port: Int) throws {


    }

    func listen() throws {
        
    }

    var closed: Bool = false

    func close() -> Bool {
        if !closed {
            closed = true
            return true
        }
        return false
    }

    func receive(max byteCount: Int) throws -> Data {
        if buffer.count == 0 {
            close()
            return []
        }

        if byteCount >= buffer.count {
            close()
            return buffer
        }

        let data = buffer.bytes[0..<byteCount]
        buffer.bytes.removeFirst(byteCount)

        let result = Data(data)
        return result
    }

    func send(data: Data) throws {

    }

    func flush() throws {

    }
}

class HTTPStreamTests: XCTestCase {

    static var allTests: [(String, HTTPStreamTests -> () throws -> Void)] {
        return [
           ("testReadRequest", testReadRequest)
        ]
    }

    func testReadRequest() throws {
        let stream = TestHTTPStream.makeStream()

        let request: Request
        do {
            request = try stream.receive()
        } catch {
            XCTFail("Error receiving from stream: \(error)")
            return
        }

        XCTAssert(request.method == Request.Method.post, "Incorrect method \(request.method)")

        print(request.headers)

        XCTAssert(request.data["hello"]?.string == "world")
    }
}
