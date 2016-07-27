import XCTest
import Node
@testable import Vapor

class TestResponder: Responder {
    var closure: (Request) throws -> Response

    init(closure: (Request) throws -> Response) {
        self.closure = closure
    }
    func respond(to request: Request) throws -> Response {
        return try closure(request)
    }
}

class ContentTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testMultipart", testMultipart),
        ("testMultipartFile", testMultipartFile),
        ("testFormURLEncoded", testFormURLEncoded),
        ("testFormURLEncodedEdge", testFormURLEncodedEdge),
        ("testSplitString", testSplitString)
    ]

    func testParse() {
        let string = "value=123"

        let data = Node(formURLEncoded: string.bytes)
        XCTAssertEqual(data["value"]?.int, 123, "Request did not parse correctly")
    }

    func testMultipart() throws {
        let boundary = "~~vapor~~"

        var body = "--" + boundary + "\r\n"
        body += "Content-Disposition: form-data; name=\"value\"\r\n"
        body += "\r\n"
        body += "123\r\n"
        body += "--" + boundary + "\r\n"
        print("Body: \(body)")
        
        let parsedBoundary = try Multipart.parseBoundary(contentType: "multipart/form-data; charset=utf-8; boundary=\(boundary)")
        print("Parsed boundary: \(parsedBoundary)")
        let data = Multipart.parse(body.bytes, boundary: parsedBoundary)
        print("Data: \(data)")
        XCTAssertEqual(data["value"]?.int, 123, "Request did not parse correctly")
    }

    func testMultipartFile() {
        let boundary = "~~vapor~~"

        var body = "--" + boundary + "\r\n"
        body += "Content-Disposition: form-data; name=\"value\"\r\n"
        body += "Content-Type: image/gif\r\n"
        body += "\r\n"
        body += "123"
        body += "--" + boundary + "\r\n"

        let parsedBoundary = try! Multipart.parseBoundary(contentType: "multipart/form-data; charset=utf-8; boundary=\(boundary)")
        print("Got parsed boundary: \(parsedBoundary)")
        let data = Multipart.parse(body.bytes, boundary: parsedBoundary)

        XCTAssertEqual(data["value"]?.file?.data ?? [1,2,3], "123".bytes, "Request did not parse correctly")
    }

    func testFormURLEncoded() {
        let body = "first=value&arr[]=foo+bar&arr[]=b%3Daz"

        let data = Node(formURLEncoded: body.bytes)

        XCTAssert(data["first"]?.string == "value", "Request key first did not parse correctly")
        XCTAssert(data["arr", 0]?.string == "foo bar", "Request key arr did not parse correctly")
        XCTAssert(data["arr", 1]?.string == "b=az", "Request key arr did not parse correctly")
    }

    func testFormURLEncodedEdge() {
        let body = "singleKeyArray[]=value&implicitArray=1&implicitArray=2"

        let data = Node(formURLEncoded: body.bytes)

        XCTAssert(data["singleKeyArray", 0]?.string == "value", "singleKeyArray did not parse correctly")
        XCTAssert(data["implicitArray", 0]?.string == "1", "implicitArray did not parse correctly")
        XCTAssert(data["implicitArray", 1]?.string == "2", "implicitArray did not parse correctly")
    }

    func testSplitString() {
        let input = "multipart/form-data; boundary=----WebKitFormBoundaryAzXMX6nUkSI9kQbq"
        let val = input.components(separatedBy: "boundary=")
        print("succeeded w/ \(val) because didn't crash")
    }

    func testCookies() {
        let cookieString = "1=1;2=2;"

        let cookies = Cookies(cookieString)
        XCTAssertEqual(cookies["1"]?.int, 1)
        XCTAssertEqual(cookies["2"]?.int, 2)
    }
}
