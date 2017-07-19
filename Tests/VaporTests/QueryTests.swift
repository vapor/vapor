import XCTest
@testable import HTTP
@testable import Vapor

class QueryTests: XCTestCase {
    static let allTests = [
        ("testPercentEncodedValues", testPercentEncodedValues),
        ("testQueryWithoutParameter", testQueryWithoutParameter),
        ("testClientQueryNotNill", testClientQueryNotNill),
        ("testQuerySetAndGet", testQuerySetAndGet),
    ]
    
    func testPercentEncodedValues() {
        let request = Request(method: .get, uri: "http://example.com?fizz=bu%3Dzz%2Bzz&aaa=bb%2Bccc%26dd")
        let query = request.query?.object
        
        XCTAssertNotNil(query)
        XCTAssertEqual(2, query?.count)
        XCTAssertEqual("bu=zz+zz", query?["fizz"]?.string)
        XCTAssertEqual("bb+ccc&dd", query?["aaa"]?.string)
    }
    
    func testQueryWithoutParameter() {
        let request = Request(method: .get, uri: "http://example.com?fizz&buzz")
        let query = request.query?.object
        
        XCTAssertNotNil(query)
        XCTAssertEqual(2, query?.count)
        XCTAssertNotNil(query?["fizz"])
        XCTAssertNotNil(query?["buzz"])
        XCTAssertEqual(query?["fizz"]?.bool, true)
    }

    func testClientQueryNotNill() throws {
        let drop = try Droplet()
        let req = try drop.client.makeRequest(.get, "https://api.spotify.com/v1/search?type=artist&q=test")
        XCTAssertNotNil(req.query)
    }
    
    func testQuerySetAndGet() throws {
        let drop = try Droplet()
        let req = try drop.client.makeRequest(.get, "https://google.com")
        req.query = Node(["q": "swift vapor"])
        let query = req.query
        XCTAssertNotNil(query)
        XCTAssertEqual(query?["q"]?.string, "swift vapor")
    }
}
