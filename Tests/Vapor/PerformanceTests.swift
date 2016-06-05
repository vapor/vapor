////
////  JeevesTests.swift
////  Vapor
////
////  Created by Logan Wright on 3/12/16.
////  Copyright © 2016 Tanner Nelson. All rights reserved.
////
//
//import XCTest
//
//@testable import Vapor
//
//final class TestPerformanceStream: HTTPListenerStream {
//    var buffer: Data
//    var handler: ((Data) -> Void)
//    var closed: Bool = false
//
//    init(request: Request, handler: ((Data) -> Void)) {
//        var data = "\(request.method) \(request.uri.path ?? "/") HTTP/1.1\r\n"
//        data += "Accept: /*/\r\n"
//        data += "\r\n"
//
//        buffer = data.data
//        self.handler = handler
//    }
//
//    enum Error: ErrorProtocol {
//        case Unsupported
//    }
//
//
//    init(address: String?, port: Int) throws {
//        fatalError("Unsupported")
//    }
//
//    func accept(max connectionCount: Int, handler: ((HTTPStream) -> Void)) throws {
//        throw Error.Unsupported
//    }
//
//    func bind() throws {
//        throw Error.Unsupported
//    }
//
//    func listen() throws {
//        throw Error.Unsupported
//    }
//
//    func close() {
//        closed = true
//    }
//
//    func receive(upTo byteCount: Int, timingOut deadline: Double = 0) throws -> Data {
//        if buffer.count == 0 {
//            close()
//            return []
//        }
//
//        if byteCount >= buffer.count {
//            close()
//            let data = buffer
//            buffer = []
//            return data
//        }
//
//        let data = buffer.bytes[0..<byteCount]
//        buffer.bytes.removeFirst(byteCount)
//
//        let result = Data(data)
//        return result
//    }
//
//    func send(_ data: Data, timingOut deadline: Double = 0) throws {
//        closed = false
//        buffer.append(contentsOf: data)
//        handler(buffer)
//    }
//
//    func flush(timingOut deadline: Double = 0) throws {
//        throw Error.Unsupported
//    }
//
//}
//
//class PerformanceTests: XCTestCase {
//
//    static var allTests: [(String, (PerformanceTests) -> () throws -> Void)] {
//        return [
//            ("testApplication", testApplication)
//        ]
//    }
//
//    func testApplication() throws {
//        let config = Config(seed: ["app" : .object(["port" : JSON(8080)])])
//        let app = Application(config: config)
//
//        app.get("plaintext") { request in
//            return "Hello, world"
//        }
//
//        app.get("json") { request in
//            return JSON(["message": "Hello, world"])
//        }
//
//
//        let server = try HTTPStreamServer<TestHTTPStream>(port: 8080, responder: app)
//        try server.start()
//
//        let stream = server.stream
//
//        let request = Request(method: .get, path: "plaintext")
//
//
//        Log.enabledLevels = [.error, .warning]
//
//        for _ in 0...100 {
//            let p = TestPerformanceStream(request: request) { data in
//            }
//            stream.handler?(p)
//        }
//    }
//}
