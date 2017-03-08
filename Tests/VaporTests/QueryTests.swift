import XCTest
@testable import HTTP
@testable import Vapor

class QueryTests: XCTestCase {
    static let allTests = [
        ("testPercentEncodedValues", testPercentEncodedValues),
        ("testQueryWithoutParameter", testQueryWithoutParameter),
    ]
    
    func testPercentEncodedValues() {
        let request = try! Request(method: .get, uri: "http://example.com?fizz=bu%3Dzz%2Bzz&aaa=bb%2Bccc%26dd")
        let query = request.query?.object
        
        XCTAssertNotNil(query)
        XCTAssertEqual(2, query?.count)
        XCTAssertEqual("bu=zz+zz", query?["fizz"]?.string)
        XCTAssertEqual("bb+ccc&dd", query?["aaa"]?.string)
    }
    
    func testQueryWithoutParameter() {
        let request = try! Request(method: .get, uri: "http://example.com?fizz&buzz")
        let query = request.query?.object
        
        XCTAssertNotNil(query)
        XCTAssertEqual(2, query?.count)
        XCTAssertNotNil(query?["fizz"])
        XCTAssertNotNil(query?["buzz"])
        XCTAssertEqual(query?["fizz"]?.bool, true)
    }
}
