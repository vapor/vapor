@testable import Vapor
import XCTest

final class URLEncodedFormParserTests: XCTestCase {
    func testBasic() throws {
        let data = "hello=world&foo=bar"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["hello": "world", "foo": "bar"])
    }
    
    func testBasicWithAmpersand() throws {
        let data = "hello=world&foo=bar%26bar"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["hello": "world", "foo": "bar&bar"])
    }

    func testDictionary() throws {
        let data = "greeting[en]=hello&greeting[es]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greeting": ["es": "hola", "en": "hello"]])
    }

    func testArray() throws {
        let data = "greetings[]=hello&greetings[]=hola"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["greetings": ["hello", "hola"]])
    }

    func testOptions() throws {
        let data = "hello=&foo"
        let normal = try URLEncodedFormParser().parse(data)
        let noEmpty = try URLEncodedFormParser(omitEmptyValues: true).parse(data)
        let noFlags = try URLEncodedFormParser(omitFlags: true).parse(data)

        XCTAssertEqual(normal, ["hello": "", "foo": "true"])
        XCTAssertEqual(noEmpty, ["foo": "true"])
        XCTAssertEqual(noFlags, ["hello": ""])
    }

    func testPercentDecoding() throws {
        let data = "aaa%5B%5D=%2Bbbb%20+ccc&d[]=1&d[]=2"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["aaa[]": "+bbb  ccc", "d": ["1","2"]])
    }

    func testNestedParsing() throws {
        // a[][b]=c&a[][b]=c
        // [a:[[b:c],[b:c]]
        let data = "a[b][c][d][hello]=world"
        let form = try URLEncodedFormParser().parse(data)
        XCTAssertEqual(form, ["a": ["b": ["c": ["d": ["hello": "world"]]]]])
    }
}
