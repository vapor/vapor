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
        let app = try Application()
        let req = Request(using: app)
        req.http.mediaType = .json
        req.http.uri.query = "hello=world"
        XCTAssertEqual(req.query["hello"], "world")
    }
    
    func testClientBasicRedirect() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        let response = try client.get("http://www.google.com/").blockingAwait()
        XCTAssertEqual(response.http.status, 200)
    }
    
    func testClientRelativeRedirect() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        let response = try client.get("http://httpbin.org/relative-redirect/5").blockingAwait()
        XCTAssertEqual(response.http.status, 200)
    }
    
    func testClientManyRelativeRedirect() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        let response = try client.get("http://httpbin.org/relative-redirect/8").blockingAwait()
        XCTAssertEqual(response.http.status, 200)
    }
    
    func testClientTooManyRelativeRedirects() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        XCTAssertThrowsError(try client.get("http://httpbin.org/relative-redirect/9").blockingAwait())
    }
    
    func testClientAbsoluteRedirect() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        let response = try client.get("http://httpbin.org/absolute-redirect/5").blockingAwait()
        XCTAssertEqual(response.http.status, 200)
    }
    
    func testClientManyAbsoluteRedirect() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        let response = try client.get("http://httpbin.org/absolute-redirect/8").blockingAwait()
        XCTAssertEqual(response.http.status, 200)
    }
    
    func testClientTooManyAbsoluteRedirects() throws {
        let app = try Application()
        
        let client = try app.make(Client.self)
        
        XCTAssertThrowsError(try client.get("http://httpbin.org/absolute-redirect/9").blockingAwait())
    }

    func testClientHeaders() throws {
        let app = try Application()
        let fakeClient = LastRequestClient(container: app)
        _ = try fakeClient.send(.get, headers: ["foo": "bar"], to: "/baz", content: "hello").await(on: app)
        if let lastReq = fakeClient.lastReq {
            XCTAssertEqual(lastReq.http.headers[.contentLength], "5")
            XCTAssertEqual(lastReq.http.headers["foo"], "bar")
            XCTAssertEqual(lastReq.http.uri.path, "/baz")
            try XCTAssertEqual(lastReq.http.body.makeData(max: 100).await(on: app), Data("hello".utf8))
        } else {
            XCTFail("No last request")
        }
    }

    static let allTests = [
        ("testContent", testContent),
        ("testComplexContent", testComplexContent),
        ("testQuery", testQuery),
        ("testClientBasicRedirect", testClientBasicRedirect),
        ("testClientRelativeRedirect", testClientRelativeRedirect),
        ("testClientManyRelativeRedirect", testClientManyRelativeRedirect),
        ("testClientTooManyRelativeRedirects", testClientTooManyRelativeRedirects),
        ("testClientAbsoluteRedirect", testClientAbsoluteRedirect),
        ("testClientManyAbsoluteRedirect", testClientManyAbsoluteRedirect),
        ("testClientTooManyAbsoluteRedirects", testClientTooManyAbsoluteRedirects),
        ("testClientHeaders", testClientHeaders)
    ]
}

/// MARK: Utilities

final class LastRequestClient: Client {
    var container: Container
    var lastReq: Request?
    init(container: Container) {
        self.container = container
    }
    func respond(to req: Request) throws -> Future<Response> {
        lastReq = req
        return Future(req.makeResponse())
    }
}

