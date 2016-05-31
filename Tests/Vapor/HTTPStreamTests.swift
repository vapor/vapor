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

class HTTPStreamTests: XCTestCase {

    static var allTests: [(String, (HTTPStreamTests) -> () throws -> Void)] {
        return [
           ("testStream", testStream)
        ]
    }

    func testStream() throws {
        let stream = TestHTTPStream()

        //MARK: Create Request
        let content = "{\"hello\": \"world\"}"

        var data = "POST /json HTTP/1.1\r\n"
        data += "Accept-Encoding: gzip, deflate\r\n"
        data += "Accept: */*\r\n"
        data += "Accept-Language: en-us\r\n"
        data += "Cookie: 1=1\r\n"
        data += "Cookie: 2=2\r\n"
        data += "Content-Type: application/json\r\n"
        data += "Content-Length: \(content.characters.count)\r\n"
        data += "\r\n"
        data += content

        //MARK: Send Request
        try stream.send(data)

        //MARK: Read Request
        var request: Request
        do {
            request = try stream.receive()
        } catch {
            XCTFail("Error receiving from stream: \(error)")
            return
        }

        request.cacheParsedContent()

        //MARK: Verify Request
        XCTAssert(request.method == Request.Method.post, "Incorrect method \(request.method)")
        XCTAssert(request.uri.path == "/json", "Incorrect path \(request.uri.path)")
        XCTAssert(request.version.major == 1 && request.version.minor == 1, "Incorrect version")
        XCTAssert(request.headers["cookie"].count == 2, "Incorrect cookies count")
        XCTAssert(request.cookies["1"] == "1" && request.cookies["2"] == "2", "Cookies not parsed")
        XCTAssert(request.data["hello"]?.string == "world")


        //MARK: Create Response
        var response = Response(status: .enhanceYourCalm, headers: [
            "Test": ["123", "456"],
            "Content-Type": "text/plain"
        ], body: { stream in
            try stream.send("Hello, world")
        })
        response.cookies["key"] = "val"

        //MARK: Send Response
        try stream.send(response, keepAlive: true)

        //MARK: Read Response
        do {
            let data = try stream.receive(upTo: Int.max)
            print(data)

            let expected = "HTTP/1.1 420 Enhance Your Calm\r\nConnection: keep-alive\r\nContent-Type: text/plain\r\nSet-Cookie: key=val\r\nTest: 123\r\nTest: 456\r\nTransfer-Encoding: chunked\r\n\r\nHello, world"

            //MARK: Verify Response
            XCTAssert(data == expected.data)
        } catch {
            XCTFail("Could not parse response string \(error)")
        }

    }
}

final class TestHTTPStream: HTTPListenerStream {
    enum Error: ErrorProtocol {
        case Closed
    }

    var buffer: Data
    var handler: ((HTTPStream) -> Void)?

    init() {
        buffer = []
    }

    convenience init(address: String?, port: Int) throws {
        self.init()
    }

    func accept(max connectionCount: Int, handler: ((HTTPStream) -> Void)) throws {
        print("Accepting max: \(connectionCount)")
        self.handler = handler
    }

    func bind() throws {
        print("Binding...")
    }

    func listen() throws {
        print("Listening...")
    }

    var closed: Bool = false

    func close() {
        if !closed {
            closed = true
        }
    }

    func receive(upTo byteCount: Int, timingOut deadline: Double = 0) throws -> Data {
        if buffer.count == 0 {
            close()
            return []
        }

        if byteCount >= buffer.count {
            close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer.bytes[0..<byteCount]
        buffer.bytes.removeFirst(byteCount)

        let result = Data(data)
        return result
    }

    func send(_ data: Data, timingOut deadline: Double = 0) throws {
        closed = false
        buffer.append(contentsOf: data)
    }

    func flush(timingOut deadline: Double = 0) throws {
        print("flushing")
        buffer = Data()
    }
}
