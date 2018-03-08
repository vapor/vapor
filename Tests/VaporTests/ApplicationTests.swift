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
        XCTAssertEqual(req.query["hello"], "world")
    }


    func testParameter() throws {
        try Application.makeTest(port: 8001) { router in
            router.get("hello", String.parameter) { req in
                return try req.parameter(String.self)
            }
        }
        .test(.GET, "/hello/vapor", equals: "vapor")
        .test(.POST, "/hello/vapor", equals: "Not found")
    }

    func testJSON() throws {
        try Application.makeTest(port: 8002) { router in
            router.get("json") { req in
                return ["foo": "bar"]
            }
        }
        .test(.GET, "/json", equals: """
        {"foo":"bar"}
        """)
    }

    static let allTests = [
        ("testContent", testContent),
        ("testComplexContent", testComplexContent),
        ("testQuery", testQuery),
        ("testParameter", testParameter),
        ("testJSON", testJSON),
    ]
}

struct ApplicationTester {
    let app: Application
    let port: Int
}

extension Application {
    static func makeTest(port: Int, configure: (Router) throws -> ()) throws -> ApplicationTester {
        let router = EngineRouter.default()
        try configure(router)
        var services = Services.default()
        services.register(router, as: Router.self)
        let app = try Application(config: .default(), environment: .testing, services: services)
        app.testRun(port: port)
        usleep(2000)
        return ApplicationTester(app: app, port: port)
    }

    func testRun(port: Int) {
        Thread.async {
            CommandInput.commandLine = CommandInput(arguments: ["vapor", "--port", port.description])
            try! self.run()
        }
    }
}

extension ApplicationTester {
    @discardableResult
    func test(_ method: HTTPMethod, _ path: String, equals string: String) throws -> ApplicationTester {
        let res = try FoundationClient.default(on: app).send(method, to: "http://localhost:\(port)" + path).wait()
        XCTAssertEqual(String(data: res.http.body.data ?? Data(), encoding: .utf8), string)
        return self
    }
}
