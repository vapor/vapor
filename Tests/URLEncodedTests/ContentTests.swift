import XCTest
import HTTP
import URLEncoded
import JSON

class ContentTests: XCTestCase {
    func testRequestSetJSONBody() throws {
        let request = Request(method: .get, path: "/")
        let json = JSON.object(["hello": .string("world")])
        request.json = json
        XCTAssertEqual(json, request.json)
    }

    /// Ensure form encoding is handled properly
    func testPlusEncoding() throws {
        let data = URLEncodedForm.dictionary(["aaa": .string("+bbb ccc")])
        let encoded = try data.serialize().makeString()
        XCTAssertEqual("aaa=+bbb ccc", encoded)
    }

    func testNested() throws {
        let data: URLEncodedForm = ["key": ["subKey1": "value1", "subKey2": "value2"]]
        let encoded = try data.serialize().makeString()
        // could equal either because dictionaries are unordered
        XCTAssert(encoded == "key[subKey2]=value2&key[subKey1]=value1" || encoded == "key[subKey1]=value1&key[subKey2]=value2")
    }

    func testArray() throws {
        let data: URLEncodedForm = ["key": ["1", "2", "3"]]
        let encoded = try data.serialize().makeString()
        XCTAssertEqual("key[]=1&key[]=2&key[]=3", encoded)
    }

    func testRequestSetFormURLEncodedBody() throws {
        let request = Request(method: .post, path: "/")
        let data: URLEncodedForm = ["hello": "world"]
        try request.content(data)
        try XCTAssertEqual(data, request.content(URLEncodedForm.self))
        XCTAssertEqual("application/x-www-form-urlencoded; charset=utf-8", request.headers["Content-Type"])
        XCTAssertNotNil(request.body.bytes)
        let bodyString = request.body.bytes!.makeString().removingPercentEncoding
        XCTAssertEqual("hello=world", bodyString)
    }

    func testRequestGetFormURLEncodedBody() throws {
        let request = Request(method: .post, path: "/")
        request.headers["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = Body("hello=world")
        let data = try request.content(URLEncodedForm.self)
        
        XCTAssertNotNil(data)
        XCTAssertEqual(["hello": "world"], data)
    }

    func testRequestGetFormURLEncodedBodyInvalidHeader() throws {
        let request = Request(method: .post, path: "/")
        request.headers["Content-Type"] = "application/json"
        request.body = Body("hello=world")
        let data = try request.content(URLEncodedForm.self)
        
        XCTAssertNil(data)
    }

    func testParse() throws {
        let string = "value=123&emptyString=&isTrue"
        let data = try URLEncodedForm.parse(data: string.data(using: .utf8)!)
        XCTAssertEqual(data["value"]?.int, 123, "Request did not parse correctly")
        XCTAssertEqual(data["emptyString"]?.string, "")
        XCTAssertEqual(data["isTrue"]?.bool, true)
    }

    func testFormURLEncoded() throws {
        let string = "first=value&arr[]=foo+bar&arr[]=b%3Daz"
        let data = try URLEncodedForm.parse(data: string.data(using: .utf8)!)
        print(data)
        XCTAssert(data["first"]?.string == "value", "Request key first did not parse correctly")
        XCTAssert(data["arr", 0]?.string == "foo bar", "Request key arr did not parse correctly")
        XCTAssert(data["arr", 1]?.string == "b=az", "Request key arr did not parse correctly")
    }

    func testFormURLEncodedEdge() throws {
        let string = "singleKeyArray[]=value&implicitArray=1&implicitArray=2"
        let data = try URLEncodedForm.parse(data: string.data(using: .utf8)!)

        XCTAssert(data["singleKeyArray", 0]?.string == "value", "singleKeyArray did not parse correctly")
        XCTAssert(data["implicitArray", 0]?.string == "1", "implicitArray did not parse correctly")
        XCTAssert(data["implicitArray", 1]?.string == "2", "implicitArray did not parse correctly")
    }

    func testFormURLEncodedDict() throws {
        let string = "obj[foo]=bar&obj[soo]=car"
        let data = try URLEncodedForm.parse(data: string.data(using: .utf8)!)
        XCTAssertEqual(data["obj", "foo"], "bar")
        XCTAssertEqual(data["obj", "foo"], "bar")
    }

    func testSplitString() {
        let input = "multipart/form-data; boundary=----WebKitFormBoundaryAzXMX6nUkSI9kQbq"
        let val = input.components(separatedBy: "boundary=")
        print("succeeded w/ \(val) because didn't crash")
    }

    func testEmptyQuery() throws {
        let req = Request(method: .get, uri: "https://fake.com")
        req.query = [:]
        XCTAssertNil(req.query)
    }
    
    static var allTests = [
        ("testRequestSetJSONBody", testRequestSetJSONBody),
        ("testRequestSetFormURLEncodedBody", testRequestSetFormURLEncodedBody),
        ("testRequestGetFormURLEncodedBody", testRequestGetFormURLEncodedBody),
        ("testRequestGetFormURLEncodedBodyInvalidHeader", testRequestGetFormURLEncodedBodyInvalidHeader),
        ("testParse", testParse),
        ("testFormURLEncoded", testFormURLEncoded),
        ("testFormURLEncodedEdge", testFormURLEncodedEdge),
        ("testFormURLEncodedDict", testFormURLEncodedDict),
        ("testSplitString", testSplitString),
        ("testEmptyQuery", testEmptyQuery),
    ]
}

class TestResponder: Responder {
    var closure: (Request) throws -> Response
    
    init(closure: @escaping (Request) throws -> Response) {
        self.closure = closure
    }
    func respond(to request: Request) throws -> Response {
        return try closure(request)
    }
}
