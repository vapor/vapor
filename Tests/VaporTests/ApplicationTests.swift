import Vapor
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
            
            router.get("raw", String.parameter, String.parameter) { req in
                return req.parameters.rawValues(for: String.self)
            }
        }

        try app.clientTest(.GET, "/hello/vapor", equals: "vapor")
        try app.clientTest(.POST, "/hello/vapor", equals: "Not found")
        
        try app.clientTest(.GET, "/raw/vapor/development", equals: "[\"vapor\",\"development\"]")
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
                let res = req.response()
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
            XCTAssertEqual(res.http.body.string.contains("Content-Disposition: form-data; name=\"name\""), true)
            XCTAssertEqual(res.http.body.string.contains("--\(boundary)"), true)
            XCTAssertEqual(res.http.body.string.contains("filename=\"droplet.png\""), true)
            XCTAssertEqual(res.http.body.string.contains("name=\"image\""), true)
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

    func testStreamFile() throws {
        try Application.runningTest(port: 8085) { router in
            router.get("file-stream") { req -> Future<Response> in
                return try req.streamFile(at: #file)
            }
        }.clientTest(.GET, "file-stream") { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.http.headers[.eTag])
            XCTAssert(res.http.body.string.contains(test))
        }
    }

    func testCustomEncode() throws {
        try Application.makeTest { router in
            router.get("custom-encode") { req -> Response in
                let res = req.response(http: .init(status: .ok))
                try res.content.encode(json: ["hello": "world"], using: .custom(format: .prettyPrinted))
                return res
            }
        }.test(.GET, "custom-encode") { res in
            XCTAssertEqual(res.http.body.string, """
            {
              "hello" : "world"
            }
            """)
        }
    }

    // https://github.com/vapor/vapor/issues/1609
    func testGH1609() throws {
        struct DecodeFail: Content {
            var here: String
            var missing: String
        }
        try Application.runningTest(port: 8086) { router in
            router.post(DecodeFail.self, at: "decode-fail") { req, fail -> String in
                return "ok"
            }
        }.clientTest(.POST, "decode-fail", beforeSend: { try $0.content.encode(["here": "hi"]) }) { res in
            XCTAssertEqual(res.http.status, .badRequest)
            XCTAssert(res.http.body.string.contains("missing"))
        }
    }

    func testValidationError() throws {
        struct User: Content, Validatable, Reflectable {
            static func validations() throws -> Validations<User> {
                var validations = Validations(User.self)
                try validations.add(\.email, .email)
                return validations
            }

            var name: String
            var email: String
        }
        try Application.makeTest { router in
            router.post(User.self, at: "users") { req, user -> String in
                try user.validate()
                return "ok"
            }
        }.test(.POST, "users", beforeSend: {
            try $0.content.encode(["name": "vapor", "email": "foo"])
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .badRequest)
            XCTAssert(res.http.body.string.contains("'email' is not a valid email address"))
        })
    }

    func testAnyResponse() throws {
        try Application.makeTest { router in
            router.get("foo") { req -> AnyResponse in
                if try req.query.get(String.self, at: "number").bool == true {
                    return AnyResponse(42)
                } else {
                    return AnyResponse("string")
                }
            }
        }.test(.GET, "foo", beforeSend: {
            try $0.query.encode(["number": "true"])
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.body.string, "42")
        }).test(.GET, "foo", beforeSend: {
            try $0.query.encode(["number": "false"])
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.body.string, "string")
        })
    }

    func testEnumResponse() throws {
        enum IntOrString: ResponseEncodable {
            case int(Int)
            case string(String)

            func encode(for req: Request) throws -> EventLoopFuture<Response> {
                switch self {
                case .int(let i): return try i.encode(for: req)
                case .string(let s): return try s.encode(for: req)
                }
            }
        }
        try Application.makeTest { router in
            router.get("foo") { req -> IntOrString in
                if try req.query.get(String.self, at: "number").bool == true {
                    return .int(42)
                } else {
                    return .string("string")
                }
            }
        }.test(.GET, "foo", beforeSend: {
            try $0.query.encode(["number": "true"])
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.body.string, "42")
        }).test(.GET, "foo", beforeSend: {
            try $0.query.encode(["number": "false"])
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.body.string, "string")
        })
    }

    func testVaporProvider() throws {
        final class FooProvider: VaporProvider {
            var willRun: Bool = false
            var didRun: Bool = false
            var didBoot: Bool = false

            func register(_ services: inout Services) throws {
                //
            }

            func didBoot(_ container: Container) throws -> Future<Void> {
                didBoot = true
                return .done(on: container)
            }

            func willRun(_ worker: Container) throws -> Future<Void> {
                willRun = true
                return .done(on: worker)
            }

            func didRun(_ worker: Container) throws -> Future<Void> {
                didRun = true
                return .done(on: worker)
            }
        }
        let foo = FooProvider()
        var services = Services.default()
        try services.register(foo)
        let app = try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
        XCTAssertEqual(foo.didBoot, true)
        XCTAssertEqual(foo.didRun, false)
        XCTAssertEqual(foo.willRun, false)
        try app.asyncRun().wait()
        XCTAssertEqual(foo.willRun, true)
        XCTAssertEqual(foo.didRun, true)
    }

    func testResponseEncodableStatus() throws {
        struct User: Content {
            var name: String
        }

        try Application.makeTest { router in
            router.post("users") { req -> Future<Response> in
                return try req.content
                    .decode(User.self)
                    .encode(status: .created, for: req)
            }
        }.test(.POST, "users", beforeSend: {
            try $0.content.encode(User(name: "vapor"))
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .created)
            XCTAssertEqual(res.http.contentType, .json)
            XCTAssertEqual(res.http.body.string, """
            {"name":"vapor"}
            """)
        })
    }

    func testHeadRequest() throws {
        try Application.runningTest(port: 8007) { router in
            router.get("hello") { req -> String in
                return "hi"
            }
        }.clientTest(.HEAD, "hello", afterSend: { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.headers[.contentLength].first, "2")
            XCTAssertEqual(res.http.body.count, 0)
        })
    }

    func testInvalidCookie() throws {
        try Application.makeTest { router in
            router.grouped(SessionsMiddleware.self).get("get") { req -> String in
                return try req.session()["name"] ?? "n/a"
            }
        }.test(.GET, "get", beforeSend: { req in
            req.http.cookies["vapor-session"] = "asdf"
        }, afterSend: { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertNotNil(res.http.headers[.setCookie])
            XCTAssertEqual(res.http.body.string, "n/a")
        })
    }
    
    func testDataResponses() throws {
        // without specific content type
        try Application.makeTest { router in
            router.get("hello") { req in
                return req.response("Hello!")
            }
        }.test(.GET, "hello") { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.body.string, "Hello!")
        }

        // with specific content type
        try Application.makeTest { router in
            router.get("hello-html") { req -> Response in
                return req.response("Hey!", as: .html)
            }
        }.test(.GET, "hello-html") { res in
            XCTAssertEqual(res.http.status, .ok)
            XCTAssertEqual(res.http.contentType, MediaType.html)
            XCTAssertEqual(res.http.body.string, "Hey!")
        }
    }

    func testMiddlewareOrder() throws {
        final class OrderMiddleware: Middleware {
            static var order: [String] = []
            let pos: String
            init(_ pos: String) {
                self.pos = pos
            }
            func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
                OrderMiddleware.order.append(pos)
                return try next.respond(to: req)
            }
        }

        try Application.makeTest { router in
            router.grouped(
                OrderMiddleware("a"), OrderMiddleware("b"), OrderMiddleware("c")
            ).get("order") { req -> String in
                return "done"
            }
        }.test(.GET, "order", afterSend: { res in
            XCTAssertEqual(OrderMiddleware.order, ["a", "b", "c"])
        })
    }

    func testSessionDestroy() throws {
        final class MockKeyedCache: KeyedCache, Service {
            var ops: [String]
            init() { self.ops = [] }
            func get<D>(_ key: String, as decodable: D.Type) -> Future<D?> where D : Decodable {
                ops.append("get \(key) as \(D.self)")
                return EmbeddedEventLoop().newSucceededFuture(result: nil)
            }

            func set<E>(_ key: String, to encodable: E) -> Future<Void> where E : Encodable {
                ops.append("set \(key) to \(E.self)")
                return EmbeddedEventLoop().newSucceededFuture(result: ())
            }

            func remove(_ key: String) -> Future<Void> {
                ops.append("del \(key)")
                return EmbeddedEventLoop().newSucceededFuture(result: ())
            }
        }

        let mockCache = MockKeyedCache()
        var cookie: HTTPCookieValue?

        try Application.makeTest(configure: { config, services in
            config.prefer(KeyedCacheSessions.self, for: Sessions.self)
            config.prefer(MockKeyedCache.self, for: KeyedCache.self)
            services.register(mockCache, as: KeyedCache.self)
        }, routes: { router in
            let sessions = router.grouped(SessionsMiddleware.self)
            sessions.get("set") { req -> String in
                try req.session()["foo"] = "bar"
                return "set"
            }
            sessions.get("del") { req  -> String in
                try req.destroySession()
                return "del"
            }
        }).test(.GET, "set", afterSend: { res in
            XCTAssertEqual(res.http.body.string, "set")
            cookie = res.http.cookies["vapor-session"]
            XCTAssertNotNil(cookie)
            XCTAssertEqual(mockCache.ops, [
                "set \(cookie?.string ?? "n/a") to SessionData",
            ])
            mockCache.ops = []
        }).test(.GET, "del", beforeSend: { req in
            req.http.cookies["vapor-session"] = cookie
        }, afterSend: { res in
            XCTAssertEqual(res.http.body.string, "del")
            XCTAssertEqual(mockCache.ops, [
                "get \(cookie?.string ?? "n/a") as SessionData",
                "del \(cookie?.string ?? "n/a")",
            ])
        })
    }

    // https://github.com/vapor/vapor/issues/1687
    func testRequestQueryStringPercentEncoding() throws {
        struct TestQueryStringContainer: Content {
            var name: String
        }
        let app = try Application()
        let req = Request(using: app)
        req.http.url = URLComponents().url!
        try req.query.encode(TestQueryStringContainer(name: "Vapor Test"))
        XCTAssertEqual(req.http.url.query, "name=Vapor%20Test")
    }
    
    func testErrorMiddlewareRespondsToNotFoundError() throws {
        class NotFoundThrowingResponder: Responder {
            func respond(to req: Request) throws -> EventLoopFuture<Response> {
                throw NotFound(rootCause: nil)
            }
        }
        let app = try Application()
        let errorMiddleware = ErrorMiddleware.default(environment: app.environment, log: try app.make())

        let result = try errorMiddleware.respond(to: Request(using: app), chainingTo: NotFoundThrowingResponder()).wait()

        XCTAssertEqual(result.http.status, .notFound)
    }
    
    // https://github.com/vapor/vapor/issues/1787
    func testGH1787() throws {
        try Application.runningTest(port: 8008, routes: { router in
            router.get("no-content") { req -> String in
                throw Abort(.noContent)
            }
        }).clientTest(.GET, "no-content", afterSend: { res in
            XCTAssertEqual(res.http.status.code, 204)
        })
    }
    
    // https://github.com/vapor/vapor/issues/1786
    func testMissingBody() throws {
        struct User: Content { }
        try Application.makeTest(routes: { router in
            router.get("user") { req -> Future<User> in
                return try req.content.decode(User.self)
            }
        }).test(.GET, "user", afterSend: { res in
            XCTAssertEqual(res.http.status, .unsupportedMediaType)
        })
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
        ("testStreamFile", testStreamFile),
        ("testCustomEncode", testCustomEncode),
        ("testGH1609", testGH1609),
        ("testAnyResponse", testAnyResponse),
        ("testVaporProvider", testVaporProvider),
        ("testResponseEncodableStatus", testResponseEncodableStatus),
        ("testHeadRequest", testHeadRequest),
        ("testInvalidCookie", testInvalidCookie),
        ("testDataResponses", testDataResponses),
        ("testMiddlewareOrder", testMiddlewareOrder),
        ("testSessionDestroy", testSessionDestroy),
        ("testRequestQueryStringPercentEncoding", testRequestQueryStringPercentEncoding),
        ("testErrorMiddlewareRespondsToNotFoundError", testErrorMiddlewareRespondsToNotFoundError),
        ("testGH1787", testGH1787),
        ("testMissingBody", testMissingBody),
    ]
}

// MARK: Private

private extension Application {
    // MARK: Static

    static func makeTest(configure: (inout Config, inout Services) throws -> () = { _, _ in }, routes: (Router) throws -> ()) throws -> Application {
        var services = Services.default()
        var config = Config.default()
        try configure(&config, &services)

        let router = EngineRouter.default()
        try routes(router)
        services.register(router, as: Router.self)
        return try Application.asyncBoot(config: config, environment: .xcode, services: services).wait()
    }

    @discardableResult
    func test(
        _ method: HTTPMethod,
        _ path: String,
        beforeSend: @escaping (Request) throws -> () = { _ in },
        afterSend: @escaping (Response) throws -> ()
    ) throws  -> Application {
        let http = HTTPRequest(method: method, url: URL(string: path)!)
        return try test(http, beforeSend: beforeSend, afterSend: afterSend)
    }

    @discardableResult
    func test(
        _ http: HTTPRequest,
        beforeSend: @escaping (Request) throws -> () = { _ in },
        afterSend: @escaping (Response) throws -> ()
    ) throws -> Application {
        let promise = eventLoop.newPromise(Void.self)
        eventLoop.execute {
            let req = Request(http: http, using: self)
            do {
                try beforeSend(req)
                try self.make(Responder.self).respond(to: req).map { res in
                    try afterSend(res)
                }.cascade(promise: promise)
            } catch {
                promise.fail(error: error)
            }
        }
        try promise.futureResult.wait()
        return self
    }

    // MARK: Live

    static func runningTest(port: Int, routes: (Router) throws -> ()) throws -> Application {
        let router = EngineRouter.default()
        try routes(router)
        var services = Services.default()
        services.register(router, as: Router.self)
        let serverConfig = NIOServerConfig(
            hostname: "localhost",
            port: port,
            backlog: 8,
            workerCount: 1,
            maxBodySize: 128_000,
            reuseAddress: true,
            tcpNoDelay: true,
            webSocketMaxFrameSize: 1 << 14
        )
        services.register(serverConfig)
        let app = try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
        try app.asyncRun().wait()
        return app
    }

    func clientTest(
        _ method: HTTPMethod,
        _ path: String,
        beforeSend: (Request) throws -> () = { _ in },
        afterSend: (Response) throws -> ()
    ) throws {
        let config = try make(NIOServerConfig.self)
        let path = path.hasPrefix("/") ? path : "/\(path)"
        let req = Request(
            http: .init(method: method, url: "http://localhost:\(config.port)" + path),
            using: self
        )
        try beforeSend(req)
        let res = try FoundationClient.default(on: self).send(req).wait()
        try afterSend(res)
    }

    func clientTest(_ method: HTTPMethod, _ path: String, equals: String) throws {
        return try clientTest(method, path) { res in
            XCTAssertEqual(res.http.body.string, equals)
        }
    }
}

private extension Environment {
    static var xcode: Environment {
        return .init(name: "xcode", isRelease: false, arguments: ["xcode"])
    }
}

private extension HTTPBody {
    var string: String {
        guard let data = self.data else {
            return "<streaming>"
        }
        return String(data: data, encoding: .ascii) ?? "<non-ascii>"
    }
}

private extension Data {
    var utf8: String? {
        return String(data: self, encoding: .utf8)
    }
}
