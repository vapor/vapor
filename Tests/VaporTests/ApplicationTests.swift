import XCTVapor
import COperatingSystem

final class ApplicationTests: XCTestCase {
    func testApplicationStop() throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = Application(environment: test) { .default() }
        DispatchQueue.global().async {
            COperatingSystem.sleep(1)
            app.running?.stop()
        }
        try app.run()
    }
    
    func testURLSession() throws {
        let app = Application.create(routes: { r, c in
            let client = try c.make(URLSession.self)
            r.get("client") { request -> EventLoopFuture<String> in
                let promise = request.eventLoop.makePromise(of: String.self)
                let url = URL(string: "http://httpbin.org/status/201")!
                client.dataTask(with: URLRequest(url: url)) { data, response, error in
                    if let error = error {
                        promise.fail(error)
                    } else if let response = response as? HTTPURLResponse {
                        promise.succeed(response.statusCode.description)
                    } else {
                        promise.fail(Abort(.internalServerError))
                    }
                }.resume()
                return promise.futureResult
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "/client") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "201")
            }
            .test(.GET, "/foo") { res in
                XCTAssertEqual(res.status, .notFound)
                XCTAssertContains(res.body.string, "Not Found")
            }
    }
    
    func testFakeClient() throws {
        let app = Application.create(routes: { r, c in
            let client = try c.make(Client.self)
            r.get("client") { req in
                return client.get("http://vapor.codes").map { $0.description }
            }
        })
        defer { app.shutdown() }

        final class FakeClient: Client {
            var reqs: [ClientRequest]
            init() {
                self.reqs = []
            }
            func send(_ req: ClientRequest) -> EventLoopFuture<ClientResponse> {
                self.reqs.append(req)
                return EmbeddedEventLoop().makeSucceededFuture(.init())
            }
        }

        let client = FakeClient()

        try app.testable()
            .override(service: Client.self, with: client)
            .inMemory()
            .test(.GET, "/client") { res in
                XCTAssertEqual(res.status, .ok)
            }
        XCTAssertEqual(client.reqs[0].url.description, "http://vapor.codes")
    }
    
    func testContent() throws {
        let request = Request(
            collectedBody: .init(string: #"{"hello": "world"}"#),
            on: EmbeddedChannel()
        )
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "hello"), "world")
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
        let request = Request(collectedBody: .init(string: complexJSON), on: EmbeddedChannel())
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "batters", "batter", 1, "type"), "Chocolate")
    }

    func testQuery() throws {
        let request = Request(on: EmbeddedChannel())
        request.headers.contentType = .json
        var comps = URLComponents()
        comps.query = "hello=world"
        request.url = comps.url!
        try XCTAssertEqual(request.query.get(String.self, at: "hello"), "world")
    }

    func testParameter() throws {
        let app = Application.create(routes: { r, c in
            r.get("hello", ":a") { req in
                return req.parameters.get("a") ?? ""
            }

            r.get("hello", ":a", ":b") { req in
                return [req.parameters.get("a") ?? "", req.parameters.get("b") ?? ""]
            }
        })
        defer { app.shutdown() }
        
        try app.testable().inMemory()
            .test(.GET, "/hello/vapor") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertContains(res.body.string, "vapor")
            }
            .test(.POST, "/hello/vapor") { res in
                XCTAssertEqual(res.status, .notFound)
            }
            .test(.GET, "/hello/vapor/development") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, #"["vapor","development"]"#)
            }
    }

    func testJSON() throws {
        let app = Application.create(routes: { r, c in
            r.get("json") { req -> [String: String] in
                print(req)
                return ["foo": "bar"]
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "/json") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, #"{"foo":"bar"}"#)
            }
    }

    func testRootGet() throws {
        do {
            let app = Application.create(routes: { r, c in
                r.get("") { req -> String in
                    return "root"
                }
                r.get("foo") { req -> String in
                    return "foo"
                }
            })
            defer { app.shutdown() }

            try app.testable().inMemory()
                .test(.GET, "/") { res in
                    XCTAssertEqual(res.status, .ok)
                    XCTAssertEqual(res.body.string, "root")
                }
                .test(.GET, "/foo") { res in
                    XCTAssertEqual(res.status, .ok)
                    XCTAssertEqual(res.body.string, "foo")
                }
        }
        do {
            let app = Application.create(routes: { r, c in
                r.get { req -> String in
                    return "root"
                }
                r.get("foo") { req -> String in
                    return "foo"
                }
            })
            defer { app.shutdown() }

            try app.testable().inMemory()
                .test(.GET, "/") { res in
                    XCTAssertEqual(res.status, .ok)
                    XCTAssertEqual(res.body.string, "root")
                }
                .test(.GET, "/foo") { res in
                    XCTAssertEqual(res.status, .ok)
                    XCTAssertEqual(res.body.string, "foo")
                }
        }
    }
    
    func testLiveServer() throws {
        let app = Application.create(routes: { r, c in
            r.get("ping") { req -> String in
                return "123"
            }
        })
        defer { app.shutdown() }
        
        try app.testable().live(port: 8080)
            .test(.GET, "/ping") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "123")
            }
    }

    // https://github.com/vapor/vapor/issues/1537
    func testQueryStringRunning() throws {
        let app = Application.create(routes: { r, c in
            r.get("todos") { req in
                return "hi"
            }
        })
        defer { app.shutdown() }

        try app.testable().live(port: 8080)
            .test(.GET, "/todos?a=b") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "hi")
            }
    }

    func testGH1534() throws {
        let data = """
        {"name":"hi","bar":"asdf"}
        """

        let app = Application.create(routes: { r, c in
            r.get("decode_error") { req -> String in
                struct Foo: Decodable {
                    var name: String
                    var bar: Int
                }
                let foo = try JSONDecoder().decode(Foo.self, from: Data(data.utf8))
                return foo.name
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "/decode_error") { res in
                XCTAssertEqual(res.status, .badRequest)
                XCTAssertContains(res.body.string, "Value of type 'Int' required for key 'bar'")
            }
    }

    func testContentContainer() throws {
        struct FooContent: Content {
            var message: String = "hi"
        }
        struct FooEncodable: Encodable {
            var message: String = "hi"
        }

        let app = Application.create(routes: { r, c in
            r.get("encode") { req -> Response in
                let res = Response()
                try res.content.encode(FooContent())
                try res.content.encode(FooContent(), as: .json)
                try res.content.encode(FooEncodable(), as: .json)
                return res
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "/encode") { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertContains(res.body.string, "hi")
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
        let expected = User(name: "Vapor", age: 3, image: File(data: "<contents of image>", filename: "droplet.png"))

        struct User: Content, Equatable {
            var name: String
            var age: Int
            var image: File
        }

        let app = Application.create(routes: { r, c in
            r.get("multipart") { req -> User in
                let decoded = try req.content.decode(User.self)
                XCTAssertEqual(decoded, expected)
                return decoded
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "/multipart", headers: [
                "Content-Type": "multipart/form-data; boundary=123"
            ], body: .init(string: data)) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqualJSON(res.body.string, expected)
            }
    }

    func testMultipartEncode() throws {
        struct User: Content {
            static var defaultContentType: HTTPMediaType = .formData
            var name: String
            var age: Int
            var image: File
        }

        let app = Application.create(routes: { r, c in
            r.get("multipart") { req -> User in
                return User(name: "Vapor", age: 3, image: File(data: "<contents of image>", filename: "droplet.png"))
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory().test(.GET, "/multipart") { res in
            debugPrint(res)
            XCTAssertEqual(res.status, .ok)
            let boundary = res.headers.contentType?.parameters["boundary"] ?? "none"
            XCTAssertContains(res.body.string, "Content-Disposition: form-data; name=\"name\"")
            XCTAssertContains(res.body.string, "--\(boundary)")
            XCTAssertContains(res.body.string, "filename=\"droplet.png\"")
            XCTAssertContains(res.body.string, "name=\"image\"")
        }
    }

    func testWebSocketClient() throws {
        let app = Application.create(routes: { r, c in
            let ws = try c.make(WebSocketClient.self)
            r.get("ws") { req -> EventLoopFuture<String> in
                let promise = req.eventLoop.makePromise(of: String.self)
                return ws.connect(host: "echo.websocket.org", port: 80) { ws in
                    ws.send(text: "Hello, world!")
                    ws.onText { ws, text in
                        promise.succeed(text)
                        ws.close().cascadeFailure(to: promise)
                    }
                }.flatMap {
                    return promise.futureResult
                }
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory().test(.GET, "/ws") { res in
            debugPrint(res)
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        }
    }
//
//    func testViewResponse() throws {
//        let app = try Application.makeTest { router in
//            router.get("view") { req -> View in
//                return View(data: "<h1>hello</h1>".convertToData())
//            }
//        }
//
//        try app.test(.GET, "view") { res in
//            XCTAssertEqual(res.http.status.code, 200)
//            XCTAssertEqual(res.http.contentType, .html)
//            XCTAssertEqual(res.http.body.string, "<h1>hello</h1>")
//        }
//    }
//
//    func testURLEncodedFormDecode() throws {
//        let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7"
//
//        struct User: Content {
//            var name: String
//            var age: Int
//            var luckyNumbers: [Int]
//        }
//
//        let app = try Application.makeTest { router in
//            router.get("urlencodedform") { req -> Future<HTTPStatus> in
//                return try req.content.decode(User.self).map(to: HTTPStatus.self) { foo in
//                    XCTAssertEqual(foo.name, "Vapor")
//                    XCTAssertEqual(foo.age, 3)
//                    XCTAssertEqual(foo.luckyNumbers, [5, 7])
//                    return .ok
//                }
//            }
//        }
//
//        var req = HTTPRequest(method: .GET, url: URL(string: "/urlencodedform")!)
//        req.contentType = .urlEncodedForm
//        req.body = HTTPBody(string: data)
//
//        try app.test(req) { res in
//            XCTAssertEqual(res.http.status.code, 200)
//        }
//    }
//
//    func testURLEncodedFormEncode() throws {
//        struct User: Content {
//            static let defaultContentType: HTTPMediaType = .urlEncodedForm
//            var name: String
//            var age: Int
//            var luckyNumbers: [Int]
//        }
//
//        let app = try Application.makeTest { router in
//            router.get("urlencodedform") { req -> User in
//                return User(name: "Vapor", age: 3, luckyNumbers: [5, 7])
//            }
//        }
//
//        try app.test(.GET, "urlencodedform") { res in
//            debugPrint(res)
//            XCTAssertEqual(res.http.status.code, 200)
//            XCTAssertEqual(res.http.contentType, .urlEncodedForm)
//            XCTAssert(res.http.body.string.contains("luckyNumbers[]=5"))
//            XCTAssert(res.http.body.string.contains("luckyNumbers[]=7"))
//            XCTAssert(res.http.body.string.contains("age=3"))
//            XCTAssert(res.http.body.string.contains("name=Vapor"))
//        }
//    }
//
//    func testURLEncodedFormDecodeQuery() throws {
//        let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7"
//        struct User: Content {
//            var name: String
//            var age: Int
//            var luckyNumbers: [Int]
//        }
//
//        let app = try Application.makeTest { router in
//            router.get("urlencodedform") { req -> HTTPStatus in
//                let foo = try req.query.decode(User.self)
//                XCTAssertEqual(foo.name, "Vapor")
//                XCTAssertEqual(foo.age, 3)
//                XCTAssertEqual(foo.luckyNumbers, [5, 7])
//                return .ok
//            }
//        }
//
//        let req = HTTPRequest(method: .GET, url: URL(string: "/urlencodedform?\(data)")!)
//        try app.test(req) { res in
//            XCTAssertEqual(res.http.status.code, 200)
//        }
//    }
//
//    func testStreamFile() throws {
//        try Application.runningTest(port: 8085) { router in
//            router.get("file-stream") { req -> Future<Response> in
//                return try req.streamFile(at: #file)
//            }
//        }.clientTest(.GET, "file-stream") { res in
//            let test = "the quick brown fox"
//            XCTAssertNotNil(res.http.headers[.eTag])
//            XCTAssert(res.http.body.string.contains(test))
//        }
//    }
//
//    func testStreamFileConnectionClose() throws {
//        let app = try Application.runningTest(port: 8087) { router in
//            router.get("file-stream") { req -> Future<Response> in
//                return try req.streamFile(at: #file)
//            }
//        }
//
//        let client = try HTTPClient.connect(
//            scheme: .http,
//            hostname: "localhost",
//            port: 8087,
//            on: app,
//            onError: { XCTFail("\($0)") }
//        ).wait()
//        var req = HTTPRequest(method: .GET, url: "/file-stream")
//        req.headers.replaceOrAdd(name: .connection, value: "close")
//        let res = try client.send(req).wait()
//        let test = "the quick brown fox"
//        XCTAssertNotNil(res.headers[.eTag])
//        XCTAssert(res.body.string.contains(test))
//    }
//
//    func testCustomEncode() throws {
//        try Application.makeTest { router in
//            router.get("custom-encode") { req -> Response in
//                let res = req.response(http: .init(status: .ok))
//                try res.content.encode(json: ["hello": "world"], using: .custom(format: .prettyPrinted))
//                return res
//            }
//        }.test(.GET, "custom-encode") { res in
//            XCTAssertEqual(res.http.body.string, """
//            {
//              "hello" : "world"
//            }
//            """)
//        }
//    }
//
//    // https://github.com/vapor/vapor/issues/1609
//    func testGH1609() throws {
//        struct DecodeFail: Content {
//            var here: String
//            var missing: String
//        }
//        try Application.runningTest(port: 8086) { router in
//            router.post(DecodeFail.self, at: "decode-fail") { req, fail -> String in
//                return "ok"
//            }
//        }.clientTest(.POST, "decode-fail", beforeSend: { try $0.content.encode(["here": "hi"]) }) { res in
//            XCTAssertEqual(res.http.status, .badRequest)
//            XCTAssert(res.http.body.string.contains("missing"))
//        }
//    }
//
//    func testValidationError() throws {
//        struct User: Content, Validatable, Reflectable {
//            static func validations() throws -> Validations<User> {
//                var validations = Validations(User.self)
//                try validations.add(\.email, .email)
//                return validations
//            }
//
//            var name: String
//            var email: String
//        }
//        try Application.makeTest { router in
//            router.post(User.self, at: "users") { req, user -> String in
//                try user.validate()
//                return "ok"
//            }
//        }.test(.POST, "users", beforeSend: {
//            try $0.content.encode(["name": "vapor", "email": "foo"])
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .badRequest)
//            XCTAssert(res.http.body.string.contains("'email' is not a valid email address"))
//        })
//    }
//
//    func testAnyResponse() throws {
//        try Application.makeTest { router in
//            router.get("foo") { req -> AnyResponse in
//                if try req.query.get(String.self, at: "number").bool == true {
//                    return AnyResponse(42)
//                } else {
//                    return AnyResponse("string")
//                }
//            }
//        }.test(.GET, "foo", beforeSend: {
//            try $0.query.encode(["number": "true"])
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.body.string, "42")
//        }).test(.GET, "foo", beforeSend: {
//            try $0.query.encode(["number": "false"])
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.body.string, "string")
//        })
//    }
//
//    func testEnumResponse() throws {
//        enum IntOrString: ResponseEncodable {
//            case int(Int)
//            case string(String)
//
//            func encode(for req: Request) throws -> EventLoopFuture<Response> {
//                switch self {
//                case .int(let i): return try i.encode(for: req)
//                case .string(let s): return try s.encode(for: req)
//                }
//            }
//        }
//        try Application.makeTest { router in
//            router.get("foo") { req -> IntOrString in
//                if try req.query.get(String.self, at: "number").bool == true {
//                    return .int(42)
//                } else {
//                    return .string("string")
//                }
//            }
//        }.test(.GET, "foo", beforeSend: {
//            try $0.query.encode(["number": "true"])
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.body.string, "42")
//        }).test(.GET, "foo", beforeSend: {
//            try $0.query.encode(["number": "false"])
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.body.string, "string")
//        })
//    }
//
//    func testVaporProvider() throws {
//        final class FooProvider: VaporProvider {
//            var willRun: Bool = false
//            var didRun: Bool = false
//            var didBoot: Bool = false
//
//            func register(_ services: inout Services) throws {
//                //
//            }
//
//            func didBoot(_ container: Container) throws -> Future<Void> {
//                didBoot = true
//                return .done(on: container)
//            }
//
//            func willRun(_ worker: Container) throws -> Future<Void> {
//                willRun = true
//                return .done(on: worker)
//            }
//
//            func didRun(_ worker: Container) throws -> Future<Void> {
//                didRun = true
//                return .done(on: worker)
//            }
//        }
//        let foo = FooProvider()
//        var services = Services.default()
//        try services.register(foo)
//        let app = try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
//        XCTAssertEqual(foo.didBoot, true)
//        XCTAssertEqual(foo.didRun, false)
//        XCTAssertEqual(foo.willRun, false)
//        try app.asyncRun().wait()
//        XCTAssertEqual(foo.willRun, true)
//        XCTAssertEqual(foo.didRun, true)
//    }
//
//    func testResponseEncodableStatus() throws {
//        struct User: Content {
//            var name: String
//        }
//
//        try Application.makeTest { router in
//            router.post("users") { req -> Future<Response> in
//                return try req.content
//                    .decode(User.self)
//                    .encode(status: .created, for: req)
//            }
//        }.test(.POST, "users", beforeSend: {
//            try $0.content.encode(User(name: "vapor"))
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .created)
//            XCTAssertEqual(res.http.contentType, .json)
//            XCTAssertEqual(res.http.body.string, """
//            {"name":"vapor"}
//            """)
//        })
//    }
//
//    func testHeadRequest() throws {
//        try Application.runningTest(port: 8007) { router in
//            router.get("hello") { req -> String in
//                return "hi"
//            }
//        }.clientTest(.HEAD, "hello", afterSend: { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.headers[.contentLength].first, "2")
//            XCTAssertEqual(res.http.body.count, 0)
//        })
//    }
//
//    func testInvalidCookie() throws {
//        try Application.makeTest { router in
//            router.grouped(SessionsMiddleware.self).get("get") { req -> String in
//                return try req.session()["name"] ?? "n/a"
//            }
//        }.test(.GET, "get", beforeSend: { req in
//            req.http.cookies["vapor-session"] = "asdf"
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertNotNil(res.http.headers[.setCookie])
//            XCTAssertEqual(res.http.body.string, "n/a")
//        })
//    }
//
//    func testDataResponses() throws {
//        // without specific content type
//        try Application.makeTest { router in
//            router.get("hello") { req in
//                return req.response("Hello!")
//            }
//        }.test(.GET, "hello") { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.body.string, "Hello!")
//        }
//
//        // with specific content type
//        try Application.makeTest { router in
//            router.get("hello-html") { req -> Response in
//                return req.response("Hey!", as: .html)
//            }
//        }.test(.GET, "hello-html") { res in
//            XCTAssertEqual(res.http.status, .ok)
//            XCTAssertEqual(res.http.contentType, HTTPMediaType.html)
//            XCTAssertEqual(res.http.body.string, "Hey!")
//        }
//    }
//
//    func testMiddlewareOrder() throws {
//        final class OrderMiddleware: Middleware {
//            static var order: [String] = []
//            let pos: String
//            init(_ pos: String) {
//                self.pos = pos
//            }
//            func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
//                OrderMiddleware.order.append(pos)
//                return try next.respond(to: req)
//            }
//        }
//
//        try Application.makeTest { router in
//            router.grouped(
//                OrderMiddleware("a"), OrderMiddleware("b"), OrderMiddleware("c")
//            ).get("order") { req -> String in
//                return "done"
//            }
//        }.test(.GET, "order", afterSend: { res in
//            XCTAssertEqual(OrderMiddleware.order, ["a", "b", "c"])
//        })
//    }
//
//    func testSessionDestroy() throws {
//        final class MockKeyedCache: KeyedCache, Service {
//            var ops: [String]
//            init() { self.ops = [] }
//            func get<D>(_ key: String, as decodable: D.Type) -> Future<D?> where D : Decodable {
//                ops.append("get \(key) as \(D.self)")
//                return EmbeddedEventLoop().newSucceededFuture(result: nil)
//            }
//
//            func set<E>(_ key: String, to encodable: E) -> Future<Void> where E : Encodable {
//                ops.append("set \(key) to \(E.self)")
//                return EmbeddedEventLoop().newSucceededFuture(result: ())
//            }
//
//            func remove(_ key: String) -> Future<Void> {
//                ops.append("del \(key)")
//                return EmbeddedEventLoop().newSucceededFuture(result: ())
//            }
//        }
//
//        let mockCache = MockKeyedCache()
//        var cookie: HTTPCookieValue?
//
//        try Application.makeTest(configure: { config, services in
//            config.prefer(KeyedCacheSessions.self, for: Sessions.self)
//            config.prefer(MockKeyedCache.self, for: KeyedCache.self)
//            services.register(mockCache, as: KeyedCache.self)
//        }, routes: { router in
//            let sessions = router.grouped(SessionsMiddleware.self)
//            sessions.get("set") { req -> String in
//                try req.session()["foo"] = "bar"
//                return "set"
//            }
//            sessions.get("del") { req  -> String in
//                try req.destroySession()
//                return "del"
//            }
//        }).test(.GET, "set", afterSend: { res in
//            XCTAssertEqual(res.http.body.string, "set")
//            cookie = res.http.cookies["vapor-session"]
//            XCTAssertNotNil(cookie)
//            XCTAssertEqual(mockCache.ops, [
//                "set \(cookie?.string ?? "n/a") to SessionData",
//            ])
//            mockCache.ops = []
//        }).test(.GET, "del", beforeSend: { req in
//            req.http.cookies["vapor-session"] = cookie
//        }, afterSend: { res in
//            XCTAssertEqual(res.http.body.string, "del")
//            XCTAssertEqual(mockCache.ops, [
//                "get \(cookie?.string ?? "n/a") as SessionData",
//                "del \(cookie?.string ?? "n/a")",
//            ])
//        })
//    }
//
//    // https://github.com/vapor/vapor/issues/1687
//    func testRequestQueryStringPercentEncoding() throws {
//        struct TestQueryStringContainer: Content {
//            var name: String
//        }
//        let app = try Application()
//        let req = Request(using: app)
//        req.http.url = URLComponents().url!
//        try req.query.encode(TestQueryStringContainer(name: "Vapor Test"))
//        // TODO: Change this test once URLEncodedForm is updated.
//        XCTAssertTrue(
//            req.http.url.query == "name=Vapor%20Test" ||
//            req.http.url.query == "name=Vapor+Test"
//        )
//        // XCTAssertEqual(req.http.url.query, "name=Vapor+Test")
//    }
//
//    func testErrorMiddlewareRespondsToNotFoundError() throws {
//        class NotFoundThrowingResponder: Responder {
//            func respond(to req: Request) throws -> EventLoopFuture<Response> {
//                throw NotFound(rootCause: nil)
//            }
//        }
//        let app = try Application()
//        let errorMiddleware = ErrorMiddleware.default(environment: app.environment, log: try app.make())
//
//        let result = try errorMiddleware.respond(to: Request(using: app), chainingTo: NotFoundThrowingResponder()).wait()
//
//        XCTAssertEqual(result.http.status, .notFound)
//    }
//
//    // https://github.com/vapor/vapor/issues/1787
//    func testGH1787() throws {
//        try Application.runningTest(port: 8008, routes: { router in
//            router.get("no-content") { req -> String in
//                throw Abort(.noContent)
//            }
//        }).clientTest(.GET, "no-content", afterSend: { res in
//            XCTAssertEqual(res.http.status.code, 204)
//        })
//    }
//
//    // https://github.com/vapor/vapor/issues/1786
//    func testMissingBody() throws {
//        struct User: Content { }
//        try Application.makeTest(routes: { router in
//            router.get("user") { req -> Future<User> in
//                return try req.content.decode(User.self)
//            }
//        }).test(.GET, "user", afterSend: { res in
//            XCTAssertEqual(res.http.status, .unsupportedMediaType)
//        })
//    }
//
//    func testSwiftError() throws {
//        struct Foo: Error { }
//        try Application.makeTest(routes: { router in
//            router.get("error") { req -> String in
//                throw Foo()
//            }
//        }).test(.GET, "error", afterSend: { res in
//            XCTAssertEqual(res.http.status, .internalServerError)
//        })
//    }
//
//    func testDebuggableError() throws {
//        struct Foo: Debuggable, Error {
//            var identifier: String
//            var reason: String
//            var sourceLocation: SourceLocation?
//            init(
//                identifier: String,
//                reason: String,
//                file: String = #file,
//                function: String = #function,
//                line: UInt = #line,
//                column: UInt = #column
//            ) {
//                self.identifier = identifier
//                self.reason = reason
//                self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
//            }
//        }
//        try Application.makeTest(routes: { router in
//            router.get("error") { req -> String in
//                throw Foo(identifier: "test", reason: "For testing error output.")
//            }
//        }).test(.GET, "error", afterSend: { res in
//            XCTAssertEqual(res.http.status, .internalServerError)
//        })
//    }
    
    func testDotEnvRead() throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let pool = NIOThreadPool(numberOfThreads: 1)
        pool.start()
        let fileio = NonBlockingFileIO(threadPool: pool)
        let folder = #file.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/test.env"
        let file = try DotEnvFile.read(path: path, fileio: fileio, on: elg.next()).wait()
        let test = file.lines.map { $0.description }.joined(separator: "\n")
        XCTAssertEqual(test, """
        NODE_ENV=development
        BASIC=basic
        AFTER_LINE=after_line
        UNDEFINED_EXPAND=$TOTALLY_UNDEFINED_ENV_KEY
        EMPTY=
        SINGLE_QUOTES=single_quotes
        DOUBLE_QUOTES=double_quotes
        EXPAND_NEWLINES=expand\nnewlines
        DONT_EXPAND_NEWLINES_1=dontexpand\\nnewlines
        DONT_EXPAND_NEWLINES_2=dontexpand\\nnewlines
        EQUAL_SIGNS=equals==
        RETAIN_INNER_QUOTES={"foo": "bar"}
        RETAIN_INNER_QUOTES_AS_STRING={"foo": "bar"}
        INCLUDE_SPACE=some spaced out string
        USERNAME=therealnerdybeast@example.tld
        """)
        try pool.syncShutdownGracefully()
        try elg.syncShutdownGracefully()
    }

//
//    static let allTests = [
//        ("testContent", testContent),
//        ("testComplexContent", testComplexContent),
//        ("testQuery", testQuery),
//        ("testParameter", testParameter),
//        ("testJSON", testJSON),
//        ("testGH1537", testGH1537),
//        ("testGH1534", testGH1534),
//        ("testContentContainer", testContentContainer),
//        ("testMultipartDecode", testMultipartDecode),
//        ("testMultipartEncode", testMultipartEncode),
//        ("testViewResponse", testViewResponse),
//        ("testURLEncodedFormDecode", testURLEncodedFormDecode),
//        ("testURLEncodedFormEncode", testURLEncodedFormEncode),
//        ("testURLEncodedFormDecodeQuery", testURLEncodedFormDecodeQuery),
//        ("testStreamFile", testStreamFile),
//        ("testStreamFileConnectionClose", testStreamFileConnectionClose),
//        ("testCustomEncode", testCustomEncode),
//        ("testGH1609", testGH1609),
//        ("testAnyResponse", testAnyResponse),
//        ("testVaporProvider", testVaporProvider),
//        ("testResponseEncodableStatus", testResponseEncodableStatus),
//        ("testHeadRequest", testHeadRequest),
//        ("testInvalidCookie", testInvalidCookie),
//        ("testDataResponses", testDataResponses),
//        ("testMiddlewareOrder", testMiddlewareOrder),
//        ("testSessionDestroy", testSessionDestroy),
//        ("testRequestQueryStringPercentEncoding", testRequestQueryStringPercentEncoding),
//        ("testErrorMiddlewareRespondsToNotFoundError", testErrorMiddlewareRespondsToNotFoundError),
//        ("testGH1787", testGH1787),
//        ("testMissingBody", testMissingBody),
//        ("testSwiftError", testSwiftError),
//        ("testDebuggableError", testDebuggableError),
//    ]
}

// MARK: Private
//
//private extension Application {
//    // MARK: Static
//
//    static func makeTest(configure: (inout Config, inout Services) throws -> () = { _, _ in }, routes: (Router) throws -> ()) throws -> Application {
//        var services = Services.default()
//        var config = Config.default()
//        try configure(&config, &services)
//
//        let router = EngineRouter.default()
//        try routes(router)
//        services.register(router, as: Router.self)
//        return try Application.asyncBoot(config: config, environment: .xcode, services: services).wait()
//    }
//
//    @discardableResult
//    func test(
//        _ method: HTTPMethod,
//        _ path: String,
//        beforeSend: @escaping (Request) throws -> () = { _ in },
//        afterSend: @escaping (Response) throws -> ()
//    ) throws  -> Application {
//        let http = HTTPRequest(method: method, url: URL(string: path)!)
//        return try test(http, beforeSend: beforeSend, afterSend: afterSend)
//    }
//
//    @discardableResult
//    func test(
//        _ http: HTTPRequest,
//        beforeSend: @escaping (Request) throws -> () = { _ in },
//        afterSend: @escaping (Response) throws -> ()
//    ) throws -> Application {
//        let promise = eventLoop.newPromise(Void.self)
//        eventLoop.execute {
//            let req = Request(http: http, using: self)
//            do {
//                try beforeSend(req)
//                try self.make(Responder.self).respond(to: req).map { res in
//                    try afterSend(res)
//                }.cascade(promise: promise)
//            } catch {
//                promise.fail(error: error)
//            }
//        }
//        try promise.futureResult.wait()
//        return self
//    }
//
//    // MARK: Live
//
//    static func runningTest(port: Int, routes: (Router) throws -> ()) throws -> Application {
//        let router = EngineRouter.default()
//        try routes(router)
//        var services = Services.default()
//        services.register(router, as: Router.self)
//        let serverConfig = NIOServerConfig(
//            hostname: "localhost",
//            port: port,
//            backlog: 8,
//            workerCount: 1,
//            maxBodySize: 128_000,
//            reuseAddress: true,
//            tcpNoDelay: true,
//            webSocketMaxFrameSize: 1 << 14
//        )
//        services.register(serverConfig)
//        let app = try Application.asyncBoot(config: .default(), environment: .xcode, services: services).wait()
//        try app.asyncRun().wait()
//        return app
//    }
//
//    @discardableResult
//    func clientTest(
//        _ method: HTTPMethod,
//        _ path: String,
//        beforeSend: (Request) throws -> () = { _ in },
//        afterSend: (Response) throws -> ()
//    ) throws -> Application {
//        let config = try make(NIOServerConfig.self)
//        let path = path.hasPrefix("/") ? path : "/\(path)"
//        let req = Request(
//            http: .init(method: method, url: "http://localhost:\(config.port)" + path),
//            using: self
//        )
//        try beforeSend(req)
//        let res = try FoundationClient.default(on: self).send(req).wait()
//        try afterSend(res)
//        return self
//    }
//
//    @discardableResult
//    func clientTest(_ method: HTTPMethod, _ path: String, equals: String) throws -> Application {
//        return try clientTest(method, path) { res in
//            XCTAssertEqual(res.http.body.string, equals)
//        }
//    }
//}
//
//private extension Environment {
//    static var xcode: Environment {
//        return .init(name: "xcode", isRelease: false, arguments: ["xcode"])
//    }
//}
//
//private extension HTTPBody {
//    var string: String {
//        guard let data = self.data else {
//            return "<streaming>"
//        }
//        return String(data: data, encoding: .ascii) ?? "<non-ascii>"
//    }
//}
//
//private extension Data {
//    var utf8: String? {
//        return String(data: self, encoding: .utf8)
//    }
//}

extension Application {
    static func create(
        configure: @escaping (inout Services) throws -> () = { _ in },
        routes: @escaping (inout Routes, Container) throws -> () = { _, _ in }
    ) -> Application {
        return Application(environment: .testing) {
            var s = Services.default()
            try configure(&s)
            s.extend(Routes.self) { r, c in
                try routes(&r, c)
            }
            return s
        }
    }
}

private extension ByteBuffer {
    init(string: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString(string)
        self = buffer
    }
    
    var string: String? {
        return self.getString(at: self.readerIndex, length: self.readableBytes)
    }
}
