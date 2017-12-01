@testable import Vapor
import XCTest

class FormURLEncodedTests: XCTestCase {
    func testBasic() throws {
        let data = "hello=world&foo=bar".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data)
        XCTAssertEqual(form, ["hello": "world", "foo": "bar"])
    }

    func testDictionary() throws {
        let data = "greeting[en]=hello&greeting[es]=hola".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data)
        XCTAssertEqual(form, ["greeting": ["es": "hola", "en": "hello"]])
    }

    func testArray() throws {
        let data = "greetings[]=hello&greetings[]=hola".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data)
        XCTAssertEqual(form, ["greetings": ["hello", "hola"]])
    }

    func testParseOptions() throws {
        let data = "hello=&foo".data(using: .utf8)!
        let normal = try! FormURLEncodedParser.default.parse(data)
        let noEmpty = try! FormURLEncodedParser.default.parse(data, omitEmptyValues: true)
        let noFlags = try! FormURLEncodedParser.default.parse(data, omitFlags: true)

        XCTAssertEqual(normal, ["hello": "", "foo": "true"])
        XCTAssertEqual(noEmpty, ["foo": "true"])
        XCTAssertEqual(noFlags, ["hello": ""])
    }

    func testPercentDecoding() throws {
        let data = "aaa%5D=%2Bbbb%20+ccc".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data)
        XCTAssertEqual(form, ["aaa]": "+bbb  ccc"])
    }

    func testPercentEncoding() throws {
        let form: [String: FormURLEncodedData] = ["aaa]": "+bbb  ccc"]
        let data = try FormURLEncodedSerializer.default.serialize(form)
        XCTAssertEqual(String(data: data, encoding: .utf8)!, "aaa%5D=%2Bbbb%20%20ccc")
    }

    func testNestedSerialization() throws {
        let form: [String: FormURLEncodedData] = ["a": ["b": ["c": ["d": ["hello": "world"]]]]]
        let data = try FormURLEncodedSerializer.default.serialize(form)
        XCTAssertEqual(String(data: data, encoding: .utf8)!, "a[b][c][d][hello]=world")
    }

    func testNestedParsing() throws {
        // a[][b]=c&a[][b]=c
        // [a:[[b:c],[b:c]]
        let data = "a[b][c][d][hello]=world".data(using: .utf8)!
        let form = try FormURLEncodedParser.default.parse(data)
        XCTAssertEqual(form, ["a": ["b": ["c": ["d": ["hello": "world"]]]]])
    }

    static let allTests = [
        ("testBasic", testBasic),
        ("testDictionary", testDictionary),
        ("testArray", testArray),
        ("testParseOptions", testParseOptions),
        ("testPercentDecoding", testPercentDecoding),
        ("testPercentEncoding", testPercentEncoding),
        ("testNestedSerialization", testNestedSerialization),
        ("testNestedParsing", testNestedParsing),
    ]
}

