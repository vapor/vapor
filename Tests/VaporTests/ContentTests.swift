import XCTest
import Node
import HTTP
@testable import Vapor

class TestResponder: Responder {
    var closure: (Request) throws -> Response

    init(closure: @escaping (Request) throws -> Response) {
        self.closure = closure
    }
    func respond(to request: Request) throws -> Response {
        return try closure(request)
    }
}

class ContentTests: XCTestCase {
    static var allTests = [
        ("testSetJSON", testSetJSON),
        ("testParse", testParse),
        ("testMultipart", testMultipart),
        ("testMultipartFile", testMultipartFile),
        ("testFormURLEncoded", testFormURLEncoded),
        ("testFormURLEncodedEdge", testFormURLEncodedEdge),
        ("testSplitString", testSplitString),
        ("testMultipartSerialization", testMultipartSerialization),
        ("testMultipartSerializationNoFileName", testMultipartSerializationNoFileName),
        ("testMultipartSerializationNoFileType", testMultipartSerializationNoFileType)
    ]

    func testSetJSON() throws {
        let request = Request(method: .get, path: "/")
        let json = JSON(["hello": "world"])
        request.json = json
        XCTAssertEqual(json, request.json)
    }

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

    func testContent() throws {
        let content = Content()
        let json = try JSON(node: ["a": "a"])
        content.append(json)
        XCTAssertEqual(content["a"]?.string, "a")
    }

    func testContentLazyLoad() throws {
        let content = Content()
        var json: JSON? = nil
        content.append { () -> JSON in
            let js = JSON(["a": .string("a")])
            json = js
            return js
        }
        XCTAssertNil(json)
        // access lazy loads
        XCTAssertEqual(content["a"]?.string, "a")
        XCTAssertNotNil(json)
    }

    func testContentCustomLoad() throws {
        let content = Content()
        content.append { indexes in
            guard indexes.count == 1, let string = indexes.first as? String, string == "b" else { return nil }
            return "custom"
        }

        let json = try JSON(node: ["a": "a", "b": "b"])
        content.append(json)

        XCTAssertEqual(content["a"]?.string, "a")
        XCTAssertEqual(content["b"]?.string, "custom")
    }

    func testMultipartSerialization() throws {
        let file = Multipart.File(name: "profile", type: "jpg", data: "pretend real data".bytes)
        let multi = Multipart.file(file)
        let serialized = try multi.serialized(boundary: "~foo~", keyName: "image")

        var expectation = ""
        expectation += "--~foo~\r\n"
        expectation += "Content-Disposition: form-data; name=\"image\"; filename=\"profile\"\r\n"
        expectation += "Content-Type: jpg\r\n\r\n"
        expectation += "pretend real data\r\n"
        expectation += "--~foo~--\r\n"
        XCTAssertEqual(serialized.string, expectation)
    }

    func testMultipartSerializationNoFileName() throws {
        let file = Multipart.File(name: nil, type: "jpg", data: "pretend real data".bytes)
        let multi = Multipart.file(file)
        let serialized = try multi.serialized(boundary: "~foo~", keyName: "image")

        var expectation = ""
        expectation += "--~foo~\r\n"
        expectation += "Content-Disposition: form-data; name=\"image\"; filename=\"\"\r\n"
        expectation += "Content-Type: jpg\r\n\r\n"
        expectation += "pretend real data\r\n"
        expectation += "--~foo~--\r\n"
        XCTAssertEqual(serialized.string, expectation)
    }

    func testMultipartSerializationNoFileType() throws {
        let file = Multipart.File(name: nil, type: nil, data: "pretend real data".bytes)
        let multi = Multipart.file(file)
        do {
            let _ = try multi.serialized(boundary: "~foo~", keyName: "image")
            XCTFail("Expected to throw, no file type")
        } catch is MultipartSerializationError {}
    }
}
