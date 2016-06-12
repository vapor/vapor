import XCTest
@testable import Vapor

class HTTPBodyTests: XCTestCase {
    static var allTests = [
        ("testBufferParse", testBufferParse),
        ("testChunkedParse", testChunkedParse),
    ]

    func testBufferParse() {
        do {
            let expected = "hello"

            let stream = TestStream()
            try stream.send(expected)

            let body = try Body(headers: [
                "content-length": expected.count.description
            ], stream: stream)

            switch body {
            case .buffer(let data):
                XCTAssertEqual(data.string, expected)
            default:
                XCTFail("Body not buffer")
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testChunkedParse() {
        do {
            let expected = "hello world!"

            let stream = TestStream()
            let chunkStream = ChunkStream(stream: stream.sender)

            try chunkStream.send("hello worl")
            try chunkStream.send("d!")

            let body = try Body(headers: [
                "transfer-encoding": "chunked"
            ], stream: stream)

            switch body {
            case .buffer(let data):
                XCTAssertEqual(data.string, expected)
            default:
                XCTFail("Body not buffer")
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}
