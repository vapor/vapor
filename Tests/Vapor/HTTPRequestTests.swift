import XCTest
@testable import Vapor

class HTTPRequestTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testParseEdgecase", testParseEdgecase)
    ]

    func testParse() {
        do {
            let stream = TestStream()

            try stream.send("GET /plaintext HTTP/1.1")
            try stream.sendLine()
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Host: qutheory.io")
            try stream.sendLine()
            try stream.sendLine()

            let request = try HTTPParser<HTTPRequest>(stream: stream).parse()
            XCTAssertEqual(request.method, Method.get)
            XCTAssertEqual(request.uri.host, "qutheory.io")
            XCTAssertEqual(request.uri.schemePort, 80)
            XCTAssertEqual(request.uri.path, "/plaintext")
            XCTAssertEqual(request.version.major, 1)
            XCTAssertEqual(request.version.minor, 1)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseEdgecase() {
        do {
            let stream = TestStream()

            try stream.send("FOO http://qutheory.io:1337/p_2?query#fragment HTTP/4")
            try stream.sendLine()
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Content-Type: application/")
            try stream.sendLine()
            try stream.send(" json")
            try stream.sendLine()
            try stream.sendLine()

            let request = try HTTPParser<HTTPRequest>(stream: stream).parse()
            XCTAssertEqual(request.method.description, "FOO")
            XCTAssertEqual(request.uri.host, "qutheory.io")
            XCTAssertEqual(request.uri.port, 1337)
            XCTAssertEqual(request.uri.path, "/p_2")
            XCTAssertEqual(request.uri.fragment, "fragment")
            XCTAssertEqual(request.version.major, 4)
            XCTAssertEqual(request.version.minor, 0)
            XCTAssertEqual(request.headers["accept"], "*/*")
            XCTAssertEqual(request.headers["content-type"], "application/json")
        } catch {
            print("ERRRR: \(error)")
            XCTFail("\(error)")
        }
    }
}
