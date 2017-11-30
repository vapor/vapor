@testable import HTTP
import XCTest

class SerializerTests : XCTestCase {
    func testRequest() throws {
        let request = try HTTPRequest(
            method: .post,
            uri: URI(path: "/foo"),
            body: "<vapor>"
        )

        let data = Data(RequestSerializer().serialize(request))
        let expected = """
        POST /foo HTTP/1.1\r
        Content-Length: 7\r
        \r
        <vapor>
        """

        XCTAssertEqual(data, expected.data(using: .utf8))
    }
    
    func testChunkEncoder() {
        let encoder = ChunkEncoder()
        var buffer = [UInt8]("4\r\nWiki\r\n5\r\npedia\r\nE\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n".utf8)
        
        var offset = 0
        
        encoder.drain { input in
            XCTAssertEqual(Array(input), Array(buffer[offset..<offset + input.count]))
            offset += input.count
        }.catch { _ in
            fatalError()
        }.finally {
            XCTAssertEqual(offset, buffer.count)
        }
        
        func send(_ string: String) {
            [UInt8](string.utf8).withUnsafeBufferPointer(encoder.onInput)
        }
        
        send("Wiki")
        send("pedia")
        send(" in\r\n\r\nchunks.")
        encoder.close()
    }
    
    static let allTests = [
        ("testRequest", testRequest)
    ]
}
