import HTTP
import XCTest

class HTTPSerializerTests: XCTestCase {
    func testRequest() throws {
        let request = try HTTPRequest(
            method: .post,
            uri: URI(path: "/foo"),
            body: "<vapor>"
        )

        let serializer = HTTPRequestSerializer()
        serializer.message = request

        let expected = """
        POST /foo HTTP/1.1\r
        Content-Length: 7\r
        \r

        """

        var buffer = Data(count: 4096)
        let serialized = try serializer.serialize(into: buffer.withMutableByteBuffer { $0 })
        XCTAssertNil(serializer.message)
        XCTAssertEqual(serialized, 41)
        let chunk = Data(buffer[0..<serialized])
        XCTAssertEqual(expected, String(data: chunk, encoding: .utf8))
    }

    func testRequestChunked() throws {
        let request = try HTTPRequest(
            method: .post,
            uri: URI(path: "/foo"),
            body: "<vapor>"
        )

        let serializer = HTTPRequestSerializer()
        serializer.message = request

        let expected = """
        POST /foo HTTP/1.1\r
        Content-Length: 7\r
        \r

        """

        var buffer = Data(count: 8) // small size here so we require multiple runs
        var output = Data()
        while serializer.message != nil {
            let serialized = try serializer.serialize(into: buffer.withMutableByteBuffer { $0 })
            output += Data(buffer[0..<serialized])
        }
        XCTAssertNil(serializer.message)
        XCTAssertEqual(output.count, 41)
        XCTAssertEqual(expected, String(data: output, encoding: .utf8))
    }

    func testResponse() throws {
        let response = try HTTPResponse(
            status: .ok,
            body: "<vapor>"
        )

        let serializer = HTTPResponseSerializer()
        serializer.message = response

        let expected = """
        HTTP/1.1 200 OK\r
        Content-Length: 7\r
        \r

        """

        var buffer = Data(count: 4096)
        let serialized = try serializer.serialize(into: buffer.withMutableByteBuffer { $0 })
        XCTAssertNil(serializer.message)
        XCTAssertEqual(serialized, 38)
        let chunk = Data(buffer[0..<serialized])
        XCTAssertEqual(expected, String(data: chunk, encoding: .utf8))
    }

    func testResponseChunked() throws {
        let response = try HTTPResponse(
            status: .ok,
            body: "<vapor>"
        )

        let serializer = HTTPResponseSerializer()
        serializer.message = response

        let expected = """
        HTTP/1.1 200 OK\r
        Content-Length: 7\r
        \r

        """

        var buffer = Data(count: 8) // small size here so we require multiple runs
        var output = Data()
        while serializer.message != nil {
            let serialized = try serializer.serialize(into: buffer.withMutableByteBuffer { $0 })
            output += Data(buffer[0..<serialized])
        }
        XCTAssertNil(serializer.message)
        XCTAssertEqual(output.count, 38)
        XCTAssertEqual(expected, String(data: output, encoding: .utf8))
    }
    
//    func testChunkEncoder() {
//        let encoder = ChunkEncoder()
//        var buffer = [UInt8]("4\r\nWiki\r\n5\r\npedia\r\nE\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n".utf8)
//
//        var offset = 0
//
//        encoder.drain { input in
//            XCTAssertEqual(Array(input), Array(buffer[offset..<offset + input.count]))
//            offset += input.count
//        }.catch { _ in
//            fatalError()
//        }.finally {
//            XCTAssertEqual(offset, buffer.count)
//        }
//
//        func send(_ string: String) {
//            [UInt8](string.utf8).withUnsafeBufferPointer(encoder.onInput)
//        }
//
//        send("Wiki")
//        send("pedia")
//        send(" in\r\n\r\nchunks.")
//        encoder.close()
//    }

    static let allTests = [
        ("testRequest", testRequest),
        ("testRequestChunked", testRequestChunked),
        ("testResponse", testResponse),
        ("testResponseChunked", testResponseChunked),
    ]
}
