import Async
import Bits
import Dispatch
import HTTP
import Routing
import Command
@testable import Vapor
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
        try XCTAssertEqual(req.content.get(at: "hello").wait(), "world")
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

        try XCTAssertEqual(req.content.get(at: "batters", "batter", 1, "type").wait(), "Chocolate")
    }

    func testQuery() throws {
        let app = try Application()
        let req = Request(using: app)
        req.http.mediaType = .json
        var comps = URLComponents()
        comps.query = "hello=world"
        req.http.url = comps.url!
        try XCTAssertEqual(req.query.get(String.self, at: "hello"), "world")
    }


    func testParameter() throws {
        let app = try Application.runningTest(port: 8081) { router in
            router.get("hello", String.parameter) { req in
                return try req.parameter(String.self)
            }
        }

        try app.clientTest(.GET, "/hello/vapor", equals: "vapor")
        try app.clientTest(.POST, "/hello/vapor", equals: "Not found")
    }

    func testJSON() throws {
        let app = try Application.runningTest(port: 8082) { router in
            router.get("json") { req in
                return ["foo": "bar"]
            }
        }

        let expected = """
        {"foo":"bar"}
        """
        try app.clientTest(.GET, "/json", equals: expected)
    }

    func testGH1537() throws {
        let app = try Application.runningTest(port: 8083) { router in
            router.get("todos") { req in
                return "hi"
            }
        }

        try app.clientTest(.GET, "/todos?a=b", equals: "hi")

        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1) {
            print("stop")
            try! app.runningServer!.close().wait()
        }

        try app.runningServer!.onClose.wait()
    }

    func testGH1534() throws {
        let data = """
        {"name":"hi","bar":"asdf"}
        """
        
        let app = try Application.makeTest { router in
            router.get("decode_error") { req -> String in
                struct Foo: Decodable {
                    var name: String
                    var bar: Int
                }
                let foo = try JSONDecoder().decode(Foo.self, from: Data(data.utf8))
                return foo.name
            }
        }

        try app.test(.GET, "decode_error") { res in
            XCTAssertEqual(res.http.status.code, 400)
            XCTAssert(res.http.body.string.contains("Value of type 'Int' required for key 'bar'"))
        }
    }

    static let allTests = [
        ("testContent", testContent),
        ("testComplexContent", testComplexContent),
        ("testQuery", testQuery),
        ("testParameter", testParameter),
        ("testJSON", testJSON),
        ("testGH1537", testGH1537),
        ("testGH1534", testGH1534),
    ]
}

extension HTTPBody {
    var string: String {
        guard let data = self.data else {
            return "<streaming>"
        }
        return String(data: data, encoding: .ascii) ?? "<non-ascii>"
    }
}

extension Application {
    static func runningTest(port: Int, configure: (Router) throws -> ()) throws -> Application {
        let router = EngineRouter.default
        try configure(router)
        var services = Services.default()
        services.register(router, as: Router.self)
        let serverConfig = EngineServerConfig(
            hostname: "localhost",
            port: port,
            backlog: 8,
            workerCount: 1,
            maxBodySize: 128_000,
            reuseAddress: true,
            tcpNoDelay: true
        )
        services.register(serverConfig)
        let app = try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
        try app.asyncRun().wait()
        return app
    }

    static func makeTest(configure: (Router) throws -> ()) throws -> Application {
        let router = EngineRouter.default
        try configure(router)
        var services = Services.default()
        services.register(router, as: Router.self)
        return try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
    }
}

extension Application {
    func test(_ method: HTTPMethod, _ path: String, check: (Response) throws -> ()) throws {
        let http = HTTPRequest(method: method, url: URL(string: path)!)
        let req = Request(http: http, using: self)
        let res = try make(Responder.self).respond(to: req).wait()
        try check(res)
    }

    func clientTest(_ method: HTTPMethod, _ path: String, check: (Response) throws -> ()) throws {
        let config = try make(EngineServerConfig.self)
        let res = try FoundationClient.default(on: self).send(method, to: "http://localhost:\(config.port)" + path).wait()
        try check(res)
    }


    func clientTest(_ method: HTTPMethod, _ path: String, equals: String) throws {
        return try clientTest(method, path) { res in
            XCTAssertEqual(res.http.body.string, equals)
        }
    }
}

extension Environment {
    static var xcode: Environment {
        return .init(name: "xcode", isRelease: false, arguments: ["xcode"])
    }
}
