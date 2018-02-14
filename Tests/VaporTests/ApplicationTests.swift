import Async
import Bits
import Dispatch
import HTTP
import Routing
@testable import Vapor
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testContent() throws {
        let app = try Application()
        let req = Request(using: app)
        req.http.body = try """
        {
            "hello": "world"
        }
        """.makeBody()
        req.http.mediaType = .json
        try XCTAssertEqual(req.content.get(at: "hello").await(on: app), "world")
    }

    func testComplexContent() throws {
        // http://adobe.github.io/Spry/samples/data_region/JSONDataSetSample.html
        let complexJSON = """
        {
            "id": "0001",
            "type": "donut",
            "name": "Cake",
            "ppu": 0.55,
            "batters":
                {
                    "batter":
                        [
                            { "id": "1001", "type": "Regular" },
                            { "id": "1002", "type": "Chocolate" },
                            { "id": "1003", "type": "Blueberry" },
                            { "id": "1004", "type": "Devil's Food" }
                        ]
                },
            "topping":
                [
                    { "id": "5001", "type": "None" },
                    { "id": "5002", "type": "Glazed" },
                    { "id": "5005", "type": "Sugar" },
                    { "id": "5007", "type": "Powdered Sugar" },
                    { "id": "5006", "type": "Chocolate with Sprinkles" },
                    { "id": "5003", "type": "Chocolate" },
                    { "id": "5004", "type": "Maple" }
                ]
        }
        """
        let app = try Application()
        let req = Request(using: app)
        req.http.body = try complexJSON.makeBody()
        req.http.mediaType = .json

        try XCTAssertEqual(req.content.get(at: "batters", "batter", 1, "type").await(on: app), "Chocolate")
    }

    func testQuery() throws {
        /// FIXME: https://github.com/vapor/vapor/issues/1419
        return;
//        let app = try Application()
//        let req = Request(using: app)
//        req.http.mediaType = .json
//        req.http.uri.query = "hello=world"
//        XCTAssertEqual(req.query["hello"], "world")
    }

    static let allTests = [
        ("testContent", testContent),
        ("testComplexContent", testComplexContent),
        ("testQuery", testQuery),
    ]
}
