//  JeevesTests.swift
//  Vapor
//
//  Created by Logan Wright on 3/12/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest

@testable import Vapor

class HTTPStreamTests: XCTestCase {

    static var allTests: [(String, (HTTPStreamTests) -> () throws -> Void)] {
        return [
           ("testParser", testParser),
           ("testSerializer", testSerializer)
        ]
    }

    func testParser() {
        let stream = TestStream()

        //MARK: Create Request
        let content = "{\"hello\": \"world\"}"

        var data = "POST /json HTTP/1.1\r\n"
        data += "Accept-Encoding: gzip, deflate\r\n"
        data += "Accept: */*\r\n"
        data += "Accept-Language: en-us\r\n"
        data += "Cookie: 1=1;2=2\r\n"
        data += "Content-Type: application/json\r\n"
        data += "Content-Length: \(content.characters.count)\r\n"
        data += "\r\n"
        data += content

        try! stream.send(data.data, timingOut: 0)
        let parser = HTTPParser(stream: stream)

        do {
            var request = try parser.parse()

            request.cacheParsedContent()

            //MARK: Verify Request
            XCTAssert(request.method == Request.Method.post, "Incorrect method \(request.method)")
            XCTAssert(request.uri.path == "/json", "Incorrect path \(request.uri.path)")
            XCTAssert(request.version.major == 1 && request.version.minor == 1, "Incorrect version")
            XCTAssert(request.cookies["1"] == "1" && request.cookies["2"] == "2", "Cookies not parsed")
            XCTAssert(request.data["hello"]?.string == "world")
        } catch {
            XCTFail("Parsing failed: \(error)")
        }
    }

    func testSerializer() {
        //MARK: Create Response
        var response = Response(status: .enhanceYourCalm, headers: [
            "Test": "123",
            "Content-Type": "text/plain"
        ], body: { stream in
            try stream.send("Hello, world")
        })
        response.cookies["key"] = "val"

        let stream = TestStream()
        let serializer =  HTTPSerializer(stream: stream)
        do {
            try serializer.serialize(response)
        } catch {
            XCTFail("Could not serialize response: \(error)")
        }

        let data = try! stream.receive(upTo: 2048, timingOut: 0)

        let expected = "HTTP/1.1 420 Enhance Your Calm\r\nContent-Type: text/plain\r\nSet-Cookie: key=val\r\nTest: 123\r\nTransfer-Encoding: chunked\r\n\r\nHello, world"
        XCTAssert(data == expected.data, "Serialization did not match")
    }
}

final class TestStream: Stream {
    var closed: Bool
    var buffer: Data

    init() {
        closed = false
        buffer = []
    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ data: Data, timingOut deadline: Double) throws {
        closed = false
        buffer.append(contentsOf: data)
    }

    func flush(timingOut deadline: Double) throws {
        buffer = Data()
    }

    func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        if buffer.count == 0 {
            try close()
            return []
        }

        if byteCount >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer.bytes[0..<byteCount]
        buffer.bytes.removeFirst(byteCount)

        let result = Data(data)
        return result
    }
}

final class TestStreamDriver: StreamDriver {
    init() {

    }

    static func make(host: String, port: Int) throws -> Self {
        return .init()

    }
    func start(handler: (Stream) throws -> ()) throws {

    }
}
