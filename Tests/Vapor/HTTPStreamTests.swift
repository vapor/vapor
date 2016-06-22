import Foundation
import XCTest

@testable import Vapor

class HTTPStreamTests: XCTestCase {
    static let allTests = [
       ("testParser", testParser),
       ("testSerializer", testSerializer)
    ]

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

        try! stream.send(data.bytes)


        do {
            let request = try HTTPParser<Request>(stream: stream).parse()

            //MARK: Verify Request
            XCTAssert(request.method == Method.post, "Incorrect method \(request.method)")
            XCTAssert(request.uri.path == "/json", "Incorrect path \(request.uri.path)")
            XCTAssert(request.version.major == 1 && request.version.minor == 1, "Incorrect version")
        } catch {
            XCTFail("Parsing failed: \(error)")
        }
    }

    func testSerializer() {
        //MARK: Create Response
        let response = Response(
            status: .enhanceYourCalm,
            headers: [
                "Test": "123",
                "Content-Type": "text/plain"
            ],
            chunked: { stream in
                try stream.send("Hello, world")
                try stream.close()
            }
        )

        let stream = TestStream()
        let serializer = HTTPSerializer<HTTPResponse>(stream: stream)
        do {
            try serializer.serialize(response)
        } catch {
            XCTFail("Could not serialize response: \(error)")
        }

        let data = try! stream.receive(max: 2048)

        XCTAssert(data.string.contains("HTTP/1.1 420 Enhance Your Calm"))
        XCTAssert(data.string.contains("Content-Type: text/plain"))
        XCTAssert(data.string.contains("Test: 123"))
        XCTAssert(data.string.contains("Transfer-Encoding: chunked"))
        XCTAssert(data.string.contains("\r\n\r\nC\r\nHello, world\r\n0\r\n\r\n"))
    }
}

final class TestStream: Stream {
    var closed: Bool
    var buffer: Bytes

    func setTimeout(_ timeout: Double) throws {
        
    }

    init() {
        closed = false
        buffer = []
    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ bytes: Bytes) throws {
        closed = false
        buffer += bytes
    }

    func flush() throws {

    }

    func receive(max: Int) throws -> Bytes {
        if buffer.count == 0 {
            try close()
            return []
        }

        if max >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer[0..<max]
        buffer.removeFirst(max)

        return Bytes(data)
    }
}
