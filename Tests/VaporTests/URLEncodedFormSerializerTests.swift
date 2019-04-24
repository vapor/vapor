@testable import Vapor
import XCTest

final class URLEncodedFormSerializerTests: XCTestCase {
    func testPercentEncoding() throws {
        let form: [String: URLEncodedFormData] = ["aaa]": "+bbb  ccc"]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "aaa%5D=%2Bbbb%20%20ccc")
    }

    func testPercentEncodingWithAmpersand() throws {
        let form: [String: URLEncodedFormData] = ["aaa": "b%26&b"]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "aaa=b%2526&b")
    }

    func testNested() throws {
        let form: [String: URLEncodedFormData] = ["a": ["b": ["c": ["d": ["hello": "world"]]]]]
        let data = try URLEncodedFormSerializer().serialize(form)
        XCTAssertEqual(data, "a[b][c][d][hello]=world")
    }
}
