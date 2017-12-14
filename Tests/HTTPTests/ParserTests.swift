//import Async
//import Bits
//import Dispatch
//import HTTP
//import JunkDrawer
//import XCTest
//
//class ParserTests : XCTestCase {
//    func testRequest() throws {
//        let data = """
//        POST /cgi-bin/process.cgi HTTP/1.1\r
//        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
//        Host: www.tutorialspoint.com\r
//        Content-Type: text/plain\r
//        Content-Length: 5\r
//        Accept-Language: en-us\r
//        Accept-Encoding: gzip, deflate\r
//        Connection: Keep-Alive\r
//        \r
//        hello
//        """.data(using: .utf8) ?? Data()
//
//        let parser = RequestParser(maxSize: 100_000)
//        guard let req = try parser.parse(from: data) else {
//            XCTFail("No request parsed")
//            return
//        }
//
//        XCTAssertEqual(req.method, .post)
//        XCTAssertEqual(req.headers[.userAgent], "Mozilla/4.0 (compatible; MSIE5.01; Windows NT)")
//        XCTAssertEqual(req.headers[.host], "www.tutorialspoint.com")
//        XCTAssertEqual(req.headers[.contentType], "text/plain")
//        XCTAssertEqual(req.mediaType, .plainText)
//        XCTAssertEqual(req.headers[.contentLength], "5")
//        XCTAssertEqual(req.headers[.acceptLanguage], "en-us")
//        XCTAssertEqual(req.headers[.acceptEncoding], "gzip, deflate")
//        XCTAssertEqual(req.headers[.connection], "Keep-Alive")
//        
//        try req.body.withUnsafeBytes { (pointer: BytesPointer) in
//            let buffer = ByteBuffer(start: pointer, count: req.body.count)
//            XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "hello")
//        }
//    }
//
//    func testResponse() throws {
//        let data = """
//        HTTP/1.1 200 OK\r
//        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
//        Server: Apache/2.2.14 (Win32)\r
//        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
//        Content-Length: 7\r
//        Content-Type: text/html\r
//        Connection: Closed\r
//        \r
//        <vapor>
//        """.data(using: .utf8) ?? Data()
//
//        let parser = ResponseParser(maxSize: 100_000)
//        guard let res = try parser.parse(from: data) else {
//            XCTFail("No response parsed")
//            return
//        }
//
//        XCTAssertEqual(res.status, .ok)
//        XCTAssertEqual(res.headers[.date], "Mon, 27 Jul 2009 12:28:53 GMT")
//        XCTAssertEqual(res.headers[.server], "Apache/2.2.14 (Win32)")
//        XCTAssertEqual(res.headers[.lastModified], "Wed, 22 Jul 2009 19:15:56 GMT")
//        XCTAssertEqual(res.headers[.contentLength], "7")
//        XCTAssertEqual(res.headers[.contentType], "text/html")
//        XCTAssertEqual(res.mediaType, .html)
//        XCTAssertEqual(res.headers[.connection], "Closed")
//        
//        try res.body.withUnsafeBytes { (pointer: BytesPointer) in
//            let buffer = ByteBuffer(start: pointer, count: res.body.count)
//            XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "<vapor>")
//        }
//    }
//    
//    func testTooLargeRequest() throws {
//        let data = """
//        POST /cgi-bin/process.cgi HTTP/1.1\r
//        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
//        Host: www.tutorialspoint.com\r
//        Content-Type: text/plain\r
//        Content-Length: 5\r
//        Accept-Language: en-us\r
//        Accept-Encoding: gzip, deflate\r
//        Connection: Keep-Alive\r
//        \r
//        hello
//        """.data(using: .utf8) ?? Data()
//        
//        let parser = RequestParser(maxSize: data.count - 2)
//        XCTAssertThrowsError(try parser.parse(from: data))
//    }
//    
//    func testTooLargeResponse() throws {
//        let data = """
//        HTTP/1.1 200 OK\r
//        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
//        Server: Apache/2.2.14 (Win32)\r
//        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
//        Content-Length: 7\r
//        Content-Type: text/html\r
//        Connection: Closed\r
//        \r
//        <vapor>
//        """.data(using: .utf8) ?? Data()
//        
//        let parser = ResponseParser(maxSize: data.count - 2)
//        XCTAssertThrowsError(try parser.parse(from: data))
//    }
//
//    static let allTests = [
//        ("testRequest", testRequest),
//        ("testResponse", testResponse),
//        ("testTooLargeRequest", testTooLargeRequest),
//        ("testTooLargeResponse", testTooLargeResponse),
//    ]
//}
//
