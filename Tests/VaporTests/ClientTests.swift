import Async
import Bits
import Dispatch
import HTTP
import Routing
@testable import Vapor
import XCTest

class ClientTests: XCTestCase {
    func testClientBasicRedirect() throws {
        let app = try Application()

        let client = try app.make(Client.self)

        let response = try client.get("http://www.google.com/").wait()
        XCTAssertEqual(response.http.status.code, 200)
    }

    func testClientRelativeRedirect() throws {
        let app = try Application()

        let client = try app.make(Client.self)

        let response = try client.get("http://httpbin.org/relative-redirect/5").wait()
        XCTAssertEqual(response.http.status.code, 200)
    }

    func testClientManyRelativeRedirect() throws {
        let app = try Application()

        let client = try app.make(Client.self)

        let response = try client.get("http://httpbin.org/relative-redirect/8").wait()
        XCTAssertEqual(response.http.status.code, 200)
    }

    func testClientAbsoluteRedirect() throws {
        let app = try Application()

        let client = try app.make(Client.self)
        print(type(of: client))

        let response = try client.get("http://httpbin.org/absolute-redirect/5").wait()
        XCTAssertEqual(response.http.status.code, 200)
    }

    func testClientManyAbsoluteRedirect() throws {
        let app = try Application()

        let client = try app.make(Client.self)

        let response = try client.get("http://httpbin.org/absolute-redirect/8").wait()
        XCTAssertEqual(response.http.status.code, 200)
    }

    func testClientHeaders() throws {
        let app = try Application()
        let fakeClient = LastRequestClient(container: app)
        _ = try fakeClient.send(.POST, headers: ["foo": "bar"], to: "/baz") { try $0.content.encode("hello") }.wait()
        if let lastReq = fakeClient.lastReq {
            XCTAssertEqual(lastReq.http.headers["foo"].first, "bar")
            XCTAssertEqual(lastReq.http.url.path, "/baz")
            XCTAssertEqual(lastReq.http.body.data, Data("hello".utf8))
        } else {
            XCTFail("No last request")
        }
    }

    func testClientItunesAPI() throws {
        let app = try Application()
        let client = try app.make(Client.self)
        let res = try client.send(.GET, to: "https://itunes.apple.com/search?term=mapstr&country=fr&entity=software&limit=1").wait()
        let data = res.http.body.data ?? Data()
        XCTAssertEqual(String(data: data, encoding: .ascii)?.contains("iPhone"), true)
    }

    func testFoundationClientItunesAPI() throws {
        var config = Config.default()
        config.prefer(FoundationClient.self, for: Client.self)
        let app = try Application(config: config)
        let client = try app.make(Client.self)
        XCTAssert(client is FoundationClient)
        let res = try client.send(.GET, to: "https://itunes.apple.com/search?term=mapstr&country=fr&entity=software&limit=1").wait()
        let data = res.http.body.data ?? Data()
        XCTAssertEqual(String(data: data, encoding: .ascii)?.contains("iPhone"), true)
    }

    static let allTests = [
        ("testClientBasicRedirect", testClientBasicRedirect),
        ("testClientRelativeRedirect", testClientRelativeRedirect),
        ("testClientManyRelativeRedirect", testClientManyRelativeRedirect),
        ("testClientAbsoluteRedirect", testClientAbsoluteRedirect),
        ("testClientManyAbsoluteRedirect", testClientManyAbsoluteRedirect),
        ("testClientHeaders", testClientHeaders),
        ("testClientItunesAPI", testClientItunesAPI),
        ("testFoundationClientItunesAPI", testFoundationClientItunesAPI),
    ]
}

/// MARK: Utilities

final class LastRequestClient: Client {
    var container: Container
    var lastReq: Request?
    init(container: Container) {
        self.container = container
    }
    func send(_ req: Request) -> Future<Response> {
        lastReq = req
        return Future.map(on: req) { req.response() }
    }
}


