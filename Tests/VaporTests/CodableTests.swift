import XCTest
import Vapor
import Foundation
import HTTP

class CodableTests: XCTestCase {
    #if swift(>=4.0)
    private class TestModel: Codable {
        let foo: String
        let baz: Int
        let opt: String?

        init(foo: String, baz: Int, opt: String? = nil) {
            self.foo = foo
            self.baz = baz
            self.opt = opt
        }
    }

    func testDecodeJSONBodyRaw() throws {
        let request = Request(method: .post, path: "/")
        let rawJSON = "{ \"foo\": \"qux\", \"baz\": 4237846, \"opt\": \"test\" }".makeBytes()

        request.body = Body.data(rawJSON)
        let model: TestModel = try request.decodeJSONBody()
        XCTAssertEqual(model.foo, "qux")
        XCTAssertEqual(model.baz, 4237846)
        XCTAssertEqual(model.opt, "test")
    }

    func testDecodeJSONBodyWithExplicitType() throws {
        let request = Request(method: .post, path: "/")
        let rawJSON = "{ \"foo\": \"qux\", \"baz\": 4237846, \"opt\": \"test\" }".makeBytes()

        request.body = Body.data(rawJSON)
        let model = try request.decodeJSONBody(TestModel.self)
        XCTAssertEqual(model.foo, "qux")
        XCTAssertEqual(model.baz, 4237846)
        XCTAssertEqual(model.opt, "test")
    }

    func testDecodeJSONBodyInterop() throws {
        let request = Request(method: .post, path: "/")
        request.json = ["foo": "bar", "baz": 123]

        let model: TestModel = try request.decodeJSONBody()
        XCTAssertEqual(model.foo, "bar")
        XCTAssertEqual(model.baz, 123)
        XCTAssertNil(model.opt)
    }

    func testDecodeFailsWithMissingField() throws {
        let request = Request(method: .post, path: "/")
        let rawJSON = "{ \"foo\": \"qux\", \"opt\": \"test\" }".makeBytes()

        request.body = Body.data(rawJSON)

        do {
            let _: TestModel = try request.decodeJSONBody()
            XCTFail("Parsing should have failed as 'baz' was not set in JSON and is not optional")
        } catch {
        }
    }

    func testEncodeJSONBodyInterop() throws {
        let model = TestModel(foo: "bar", baz: 321)
        let request = Request(method: .post, path: "/")
        try request.encodeJSONBody(model)

        guard let json = request.json else {
            XCTFail("Could not parse JSON body set by encodeJSONBody")
            return
        }

        XCTAssertEqual("bar", try json.get("foo"))
        XCTAssertEqual(321, try json.get("baz"))
        XCTAssertNil(try json.get("opt"))
    }

    func testMakeResponse() throws {
        let model = TestModel(foo: "fedcba", baz: 33123, opt: "test")
        let response = try model.makeResponse()
        XCTAssertEqual(response.status, .ok)

        guard let json = response.json else {
            XCTFail("Could not parse JSON body set by makeResponse")
            return
        }

        XCTAssertEqual("fedcba", try json.get("foo"))
        XCTAssertEqual(33123, try json.get("baz"))
        XCTAssertEqual("test", try json.get("opt"))
    }

    static let allTests: [(String, (CodableTests) -> () throws -> ())] = [
        ("testDecodeJSONBodyRaw", testDecodeJSONBodyRaw),
        ("testDecodeJSONBodyWithExplicitType", testDecodeJSONBodyWithExplicitType),
        ("testDecodeJSONBodyInterop", testDecodeJSONBodyInterop),
        ("testDecodeFailsWithMissingField", testDecodeFailsWithMissingField),
        ("testEncodeJSONBodyInterop", testEncodeJSONBodyInterop),
        ("testMakeResponse", testMakeResponse),
    ]
    #else
    static let allTests: [(String, (CodableTests) -> () throws -> ())] = [
    ]
    #endif
}

