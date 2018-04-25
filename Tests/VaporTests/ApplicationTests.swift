@testable import Vapor
import XCTest

class ApplicationTests: XCTestCase {
    func testContent() throws {
        let app = try Application()
        let req = Request(using: app)
        req.http.body = """
        {
            "hello": "world"
        }
        """.convertToHTTPBody()
        req.http.contentType = .json
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
        req.http.body = complexJSON.convertToHTTPBody()
        req.http.contentType = .json

        try XCTAssertEqual(req.content.get(at: "batters", "batter", 1, "type").wait(), "Chocolate")
    }

    func testQuery() throws {
        let app = try Application()
        let req = Request(using: app)
        req.http.contentType = .json
        var comps = URLComponents()
        comps.query = "hello=world"
        req.http.url = comps.url!
        try XCTAssertEqual(req.query.get(String.self, at: "hello"), "world")
    }


    func testParameter() throws {
        let app = try Application.runningTest(port: 8081) { router in
            router.get("hello", String.parameter) { req in
                return try req.parameters.next(String.self)
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

    func testContentContainer() throws {
        struct FooContent: Content {
            var message: String = "hi"
        }
        struct FooEncodable: Encodable {
            var message: String = "hi"
        }

        let app = try Application.makeTest { router in
            router.get("encode") { req -> Response in
                let res = req.makeResponse()
                try res.content.encode(FooContent())
                try res.content.encode(FooContent(), as: .json)
                try res.content.encode(FooEncodable(), as: .json)
                return res
            }
        }

        try app.test(.GET, "encode") { res in
            XCTAssertEqual(res.http.status.code, 200)
            XCTAssert(res.http.body.string.contains("hi"))
        }
    }

    func testMultipartDecode() throws {
        let data = """
        --123\r
        Content-Disposition: form-data; name="name"\r
        \r
        Vapor\r
        --123\r
        Content-Disposition: form-data; name="age"\r
        \r
        3\r
        --123\r
        Content-Disposition: form-data; name="image"; filename="droplet.png"\r
        \r
        <contents of image>\r
        --123--\r

        """

        struct User: Content {
            var name: String
            var age: Int
            var image: Data
        }

        let app = try Application.makeTest { router in
            router.get("multipart") { req -> Future<User> in
                return try req.content.decode(User.self).map(to: User.self) { foo in
                    XCTAssertEqual(foo.name, "Vapor")
                    XCTAssertEqual(foo.age, 3)
                    // XCTAssertEqual(foo.image.filename, "droplet.png")
                    XCTAssertEqual(foo.image.utf8, "<contents of image>")
                    return foo
                }
            }
        }

        var req = HTTPRequest(method: .GET, url: URL(string: "/multipart")!)
        req.contentType = MediaType(type: "multipart", subType: "form-data", parameters: ["boundary": "123"])
        req.body = HTTPBody(string: data)

        try app.test(req) { res in
            XCTAssertEqual(res.http.status.code, 200)
            XCTAssert(res.http.body.string.contains("Vapor"))
        }
    }

    func testMultipartEncode() throws {
        struct User: Content {
            static var defaultContentType: MediaType = .formData
            var name: String
            var age: Int
            var image: File
        }

        let app = try Application.makeTest { router in
            router.get("multipart") { req -> User in
                return User(name: "Vapor", age: 3, image: File(data: "<contents of image>", filename: "droplet.png"))
            }
        }

        try app.test(.GET, "multipart") { res in
            debugPrint(res)
            XCTAssertEqual(res.http.status.code, 200)
            let boundary = res.http.contentType?.parameters["boundary"] ?? "none"
            XCTAssertEqual(res.http.body.string.contains("Content-Disposition: form-data; name=name"), true)
            XCTAssertEqual(res.http.body.string.contains("--\(boundary)"), true)
            XCTAssertEqual(res.http.body.string.contains("filename=droplet.png"), true)
            XCTAssertEqual(res.http.body.string.contains("name=image"), true)
        }
    }

    func testViewResponse() throws {
        let app = try Application.makeTest { router in
            router.get("view") { req -> View in
                return View(data: "<h1>hello</h1>".convertToData())
            }
        }

        try app.test(.GET, "view") { res in
            XCTAssertEqual(res.http.status.code, 200)
            XCTAssertEqual(res.http.contentType, .html)
            XCTAssertEqual(res.http.body.string, "<h1>hello</h1>")
        }
    }

    func testURLEncodedFormDecode() throws {
        let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7"

        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = try Application.makeTest { router in
            router.get("urlencodedform") { req -> Future<HTTPStatus> in
                return try req.content.decode(User.self).map(to: HTTPStatus.self) { foo in
                    XCTAssertEqual(foo.name, "Vapor")
                    XCTAssertEqual(foo.age, 3)
                    XCTAssertEqual(foo.luckyNumbers, [5, 7])
                    return .ok
                }
            }
        }

        var req = HTTPRequest(method: .GET, url: URL(string: "/urlencodedform")!)
        req.contentType = .urlEncodedForm
        req.body = HTTPBody(string: data)

        try app.test(req) { res in
            XCTAssertEqual(res.http.status.code, 200)
        }
    }

    func testURLEncodedFormEncode() throws {
        struct User: Content {
            static let defaultContentType: MediaType = .urlEncodedForm
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = try Application.makeTest { router in
            router.get("urlencodedform") { req -> User in
                return User(name: "Vapor", age: 3, luckyNumbers: [5, 7])
            }
        }

        try app.test(.GET, "urlencodedform") { res in
            debugPrint(res)
            XCTAssertEqual(res.http.status.code, 200)
            XCTAssertEqual(res.http.contentType, .urlEncodedForm)
            XCTAssert(res.http.body.string.contains("luckyNumbers[]=5"))
            XCTAssert(res.http.body.string.contains("luckyNumbers[]=7"))
            XCTAssert(res.http.body.string.contains("age=3"))
            XCTAssert(res.http.body.string.contains("name=Vapor"))
        }
    }

    func testURLEncodedFormDecodeQuery() throws {
        let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7"
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = try Application.makeTest { router in
            router.get("urlencodedform") { req -> HTTPStatus in
                let foo = try req.query.decode(User.self)
                XCTAssertEqual(foo.name, "Vapor")
                XCTAssertEqual(foo.age, 3)
                XCTAssertEqual(foo.luckyNumbers, [5, 7])
                return .ok
            }
        }

        let req = HTTPRequest(method: .GET, url: URL(string: "/urlencodedform?\(data)")!)
        try app.test(req) { res in
            XCTAssertEqual(res.http.status.code, 200)
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
        ("testContentContainer", testContentContainer),
        ("testMultipartDecode", testMultipartDecode),
        ("testMultipartEncode", testMultipartEncode),
        ("testViewResponse", testViewResponse),
        ("testURLEncodedFormDecode", testURLEncodedFormDecode),
        ("testURLEncodedFormEncode", testURLEncodedFormEncode),
        ("testURLEncodedFormDecodeQuery", testURLEncodedFormDecodeQuery),
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

extension Data {
    var utf8: String? {
        return String(data: self, encoding: .utf8)
    }
}

extension Application {
    static func runningTest(port: Int, configure: (Router) throws -> ()) throws -> Application {
        let router = EngineRouter.default()
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
        let router = EngineRouter.default()
        try configure(router)
        var services = Services.default()
        services.register(router, as: Router.self)
        return try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
    }
}

extension Application {
    func test(_ method: HTTPMethod, _ path: String, _ check: (Response) throws -> ()) throws {
        let http = HTTPRequest(method: method, url: URL(string: path)!)
        try test(http, check)
    }

    func test(_ http: HTTPRequest, _ check: (Response) throws -> ()) throws {
        let req = Request(http: http, using: self)
        let res = try make(Responder.self).respond(to: req).wait()
        try check(res)
    }

    func clientTest(_ method: HTTPMethod, _ path: String, _ check: (Response) throws -> ()) throws {
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
