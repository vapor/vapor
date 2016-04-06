//
//  JeevesTests.swift
//  Vapor
//
//  Created by Logan Wright on 3/12/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

@testable import Vapor

final class TestPerformanceStream: HTTPStream {
    var buffer: Data
    var handler: (Data -> Void)

    init(request: Request, handler: (Data -> Void)) {
        var data = "\(request.method) \(request.uri.path ?? "/") HTTP/1.1\r\n"
        data += "Accept: /*/\r\n"
        data += "\r\n"

        buffer = data.data
        self.handler = handler
    }

    enum Error: ErrorProtocol {
        case Unsupported
    }


    static func makeStream() -> TestPerformanceStream {
        fatalError("Unsupported")
    }

    func accept(max connectionCount: Int, handler: (HTTPStream -> Void)) throws {
        throw Error.Unsupported
    }

    func bind(to ip: String?, on port: Int) throws {
        throw Error.Unsupported
    }

    func listen() throws {
        throw Error.Unsupported
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
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer.bytes[0..<byteCount]
        buffer.bytes.removeFirst(byteCount)

        let result = Data(data)
        return result
    }

    func send(data: Data) throws {
        closed = false
        buffer.append(contentsOf: data)
        handler(buffer)
    }
    
    func flush() throws {
        throw Error.Unsupported
    }

}

class PerformanceTests: XCTestCase {

    static var allTests: [(String, PerformanceTests -> () throws -> Void)] {
        return [
            ("testApplication", testApplication)
        ]
    }

    func testApplication() throws {
        let app = Application()

        app.get("plaintext") { request in
            return "Hello, world"
        }

        app.get("json") { request in
            return Json(["message": "Hello, world"])
        }


        let server = HTTPStreamServer<TestHTTPStream>()
        app.server = server

        app.start()

        let stream = server.stream

        let request = Request(method: .get, path: "plaintext")


        Log.enabledLevels = [.Error, .Warning]

        for _ in 0...100 {
            let p = TestPerformanceStream(request: request) { data in
            }
            stream.handler?(p)
        }
    }
}
