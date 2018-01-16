import Async
import Bits
import Dispatch
import HTTP
import Routing
@testable import Vapor
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testAnyResponse() throws {
//        let response = "hello"
//        let app = try Application()
//        var result = Response(using: app)
//        let req = Request(using: app)
//        
//        AnyResponse(response).map { encodable in
//            try encodable.encode(to: &result, for: req).blockingAwait()
//            XCTAssertEqual(result.http.body.data, Data("hello".utf8))
//        }.catch { error in
//            XCTFail("\(error)")
//        }
//        
//        let response2: Future<String?> = Future(nil)
//        let response3: Future<String?> = Future("test")
//        
//        AnyResponse(future: response2, or: "fail").map { encodable in
//            try encodable.encode(to: &result, for: req).blockingAwait()
//            XCTAssertEqual(result.http.body.data, Data("fail".utf8))
//        }.catch { error in
//            XCTFail("\(error)")
//        }
//        
//        AnyResponse(future: response3, or: "fail").map { encodable in
//            try encodable.encode(to: &result, for: req).blockingAwait()
//            XCTAssertEqual(result.http.body.data, Data("test".utf8))
//        }.catch { error in
//            XCTFail("\(error)")
//        }
    }

    func testContent() throws {
        let app = try Application()
        let req = Request(using: app)
        req.http.mediaType = .json
        req.http.body = try """
        {
            "hello": "world"
        }
        """.makeBody()

        XCTAssertEqual(req.content["hello"], "world")
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
        req.http.mediaType = .json
        req.http.body = try complexJSON.makeBody()

        XCTAssertEqual(req.content["batters", "batter", 1, "type"], "Chocolate")
    }

    func testQuery() throws {
        /// FIXME: https://github.com/vapor/vapor/issues/1419
        return;
        
        let app = try Application()
        let req = Request(using: app)
        req.http.mediaType = .json
        req.http.uri.query = "hello=world"
        XCTAssertEqual(req.query["hello"], "world")
    }

    static let allTests = [
        ("testAnyResponse", testAnyResponse),
        ("testContent", testContent),
        ("testComplexContent", testComplexContent),
        ("testQuery", testQuery),
    ]
}
