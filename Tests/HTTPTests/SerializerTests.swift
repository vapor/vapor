import HTTP
import XCTest

class SerializerTests : XCTestCase {
    func testRequest() throws {
        let request = try Request(
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
    
    static let allTests = [
        ("testRequest", testRequest)
    ]
}
