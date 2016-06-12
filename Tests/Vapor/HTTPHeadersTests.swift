import XCTest
@testable import Vapor

class HTTPHeadersTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testMultilineValue", testMultilineValue),
        ("testValueTrimming", testValueTrimming),
        ("testLeadingWhitespaceError", testLeadingWhitespaceError),
        ("testKeyWhitespaceError", testKeyWhitespaceError),
    ]

    func testParse() {
        do {
            let stream = TestStream()

            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Host: localhost:8080")
            try stream.sendLine()
            try stream.send("Content-Type: application/json")
            try stream.sendLine()
            try stream.sendLine()

            let headers = try Headers(stream: stream)
            XCTAssertEqual(headers["accept"], "*/*")
            XCTAssertEqual(headers["host"], "localhost:8080")
            XCTAssertEqual(headers["content-type"], "application/json")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testMultilineValue() {
        do {
            let stream = TestStream()

            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Cookie: 1=1;")
            try stream.sendLine()
            try stream.send(" 2=2;")
            try stream.sendLine()
            try stream.send("Content-Type: application/json")
            try stream.sendLine()
            try stream.sendLine()

            let headers = try Headers(stream: stream)
            XCTAssertEqual(headers["cookie"], "1=1;2=2;")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testValueTrimming() {
        let value = String(headerValue: " ferret\t".bytes)
        XCTAssertEqual(value, "ferret")
    }

    func testLeadingWhitespaceError() {
        do {
            let stream = TestStream()

            try stream.send(" ") // this is bad
            try stream.send("Accept: */*")
            try stream.sendLine()
            try stream.send("Content-Type: application/json")
            try stream.sendLine()
            try stream.sendLine()

            _ = try Headers(stream: stream)
            XCTFail("Headers init should have thrown")
        } catch Headers.ParseError.invalidLeadingWhitespace {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testKeyWhitespaceError() {
        do {
            let stream = TestStream()
            try stream.send("Accept : */*")
            //                     ^ this is bad
            try stream.sendLine()
            try stream.send("Content-Type: application/json")
            try stream.sendLine()
            try stream.sendLine()

            _ = try Headers(stream: stream)
            XCTFail("Headers init should have thrown")
        } catch Headers.ParseError.invalidKeyWhitespace {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
