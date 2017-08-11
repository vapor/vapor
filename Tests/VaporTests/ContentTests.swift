import XCTest
import Node
import HTTP
@testable import Vapor
import JSONs

class ContentTests: XCTestCase {
    func testRequestSetJSONBody() throws {
        let request = Request(method: .get, path: "/")
        let json = JSON.object(["hello": .string("world")])
        request.json = json
        XCTAssertEqual(json, request.json)
    }

    func testRequestSetFormURLEncodedBody() throws {
        let request = Request(method: .post, path: "/")
        let data = Node(["hello": "world"])
        request.formURLEncoded = data
        XCTAssertEqual(data, request.formURLEncoded)
        XCTAssertEqual("application/x-www-form-urlencoded", request.headers["Content-Type"])
        XCTAssertNotNil(request.body.bytes)
        let bodyString = request.body.bytes!.makeString().removingPercentEncoding
        XCTAssertEqual("hello=world", bodyString)
    }

    func testRequestGetFormURLEncodedBody() throws {
        let request = Request(method: .post, path: "/")
        request.headers["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = Body("hello=world")
        let data = request.formURLEncoded
        
        XCTAssertNotNil(data)
        XCTAssertEqual(["hello": "world"], data)
        
        let cached = request.storage["form-urlencoded"] as? Node
        XCTAssertNotNil(cached)
        
        if let cached = cached {
            XCTAssertEqual(["hello": "world"], cached)
        }
    }

    func testRequestGetFormURLEncodedBodyInvalidHeader() throws {
        let request = Request(method: .post, path: "/")
        request.headers["Content-Type"] = "application/json"
        request.body = Body("hello=world")
        let data = request.formURLEncoded
        
        XCTAssertNil(data)
    }

    func testParse() {
        let string = "value=123&emptyString=&isTrue"

        let data = Node(formURLEncoded: string.makeBytes(), allowEmptyValues: true)
        print(data)
        XCTAssertEqual(data["value"]?.int, 123, "Request did not parse correctly")
        XCTAssertEqual(data["emptyString"]?.string, "")
        XCTAssertEqual(data["isTrue"]?.bool, true)
    }

    func testFormURLEncoded() {
        let body = "first=value&arr[]=foo+bar&arr[]=b%3Daz"

        let data = Node(formURLEncoded: body.makeBytes(), allowEmptyValues: true)
        print(data)
        XCTAssert(data["first"]?.string == "value", "Request key first did not parse correctly")
        XCTAssert(data["arr", 0]?.string == "foo bar", "Request key arr did not parse correctly")
        XCTAssert(data["arr", 1]?.string == "b=az", "Request key arr did not parse correctly")
    }

    func testFormURLEncodedEdge() {
        let body = "singleKeyArray[]=value&implicitArray=1&implicitArray=2"

        let data = Node(formURLEncoded: body.makeBytes(), allowEmptyValues: true)

        XCTAssert(data["singleKeyArray", 0]?.string == "value", "singleKeyArray did not parse correctly")
        XCTAssert(data["implicitArray", 0]?.string == "1", "implicitArray did not parse correctly")
        XCTAssert(data["implicitArray", 1]?.string == "2", "implicitArray did not parse correctly")
    }

    func testFormURLEncodedDict() {
        let body = "obj[foo]=bar&obj[soo]=car"
        let data = Node(formURLEncoded: body.makeBytes(), allowEmptyValues: true)
        // FIXME
        // let foo = try! data.converted(to: JSON.self).makeBytes().makeString()
        // print(foo)
        XCTAssertEqual(data["obj.foo"], "bar")
        XCTAssertEqual(data["obj.foo"], "bar")
    }

    func testSplitString() {
        let input = "multipart/form-data; boundary=----WebKitFormBoundaryAzXMX6nUkSI9kQbq"
        let val = input.components(separatedBy: "boundary=")
        print("succeeded w/ \(val) because didn't crash")
    }

//    func testContent() throws {
//        let content = Content()
//        let json = try JSON(["a": "a"])
//        // FIXME
//        // content.append(json)
//        let string = try content.get("a") as String
//        XCTAssertEqual(string, "a")
//    }
//
//    func testContentLazyLoad() throws {
//        let content = Content()
//        var json: JSON? = nil
//        // FIXME
////        content.append { () -> JSON in
////            let js = JSON(["a": .string("a")])
////            json = js
////            return js
////        }
//        XCTAssertNil(json)
//        // access lazy loads
//        XCTAssertEqual(content["a"]?.string, "a")
//        XCTAssertNotNil(json)
//    }
//
//    func testContentCustomLoad() throws {
//        let content = Content()
//        content.append { indexes in
//            guard indexes.count == 1, let string = indexes.first as? String, string == "b" else { return nil }
//            return "custom"
//        }
//
//        // FIXME
//        let json = try JSON(["a": "a", "b": "b"])
//        // content.append(json)
//
//        XCTAssertEqual(content["a"]?.string, "a")
//        XCTAssertEqual(content["b"]?.string, "custom")
//    }

    func testEmptyQuery() throws {
        let req = Request(method: .get, uri: "https://fake.com")
        req.query = Node([:])
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
