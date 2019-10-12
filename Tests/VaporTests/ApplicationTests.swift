import XCTVapor
import COperatingSystem

final class ApplicationTests: XCTestCase {
    func testApplicationStop() throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = Application(environment: test)
        defer { app.shutdown() }
        try! app.boot()
        try! app.start()
        guard let running = app.running else {
            XCTFail("app started without setting 'running'")
            return
        }
        running.stop()
        try running.onStop.wait()
    }
    
//    func testURLSession() throws {
//        let app = Application.create(routes: { r, c in
//            let client = try c.make(URLSession.self)
//            r.get("client") { request -> EventLoopFuture<String> in
//                let promise = request.eventLoop.makePromise(of: String.self)
//                let url = URL(string: "http://httpbin.org/status/201")!
//                client.dataTask(with: URLRequest(url: url)) { data, response, error in
//                    if let error = error {
//                        promise.fail(error)
//                    } else if let response = response as? HTTPURLResponse {
//                        promise.succeed(response.statusCode.description)
//                    } else {
//                        promise.fail(Abort(.internalServerError))
//                    }
//                }.resume()
//                return promise.futureResult
//            }
//        })
//        defer { app.shutdown() }
//
//        try app.testable().inMemory()
//            .test(.GET, "/client") { res in
//                XCTAssertEqual(res.status, .ok)
//                XCTAssertEqual(res.body.string, "201")
//            }
//            .test(.GET, "/foo") { res in
//                XCTAssertEqual(res.status, .notFound)
//                XCTAssertContains(res.body.string, "Not Found")
//            }
//    }

    func testContent() throws {
        let request = Request(
            collectedBody: .init(string: #"{"hello": "world"}"#),
            on: EmbeddedEventLoop()
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
        let request = Request(collectedBody: .init(string: complexJSON), on: EmbeddedEventLoop())
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "batters", "batter", 1, "type"), "Chocolate")
    }

    func testQuery() throws {
        let request = Request(on: EmbeddedEventLoop())
        request.headers.contentType = .json
        request.url.path = "/foo"
        print(request.url.string)
        request.url.query = "hello=world"
        print(request.url.string)
        try XCTAssertEqual(request.query.get(String.self, at: "hello"), "world")
    }

    func testQueryGet() throws {
        var req: Request

        //
        req = Request(method: .GET, url: .init(string: "/path?foo=a"), on: EmbeddedEventLoop())

        XCTAssertEqual(try req.query.get(String.self, at: "foo"), "a")
        XCTAssertThrowsError(try req.query.get(Int.self, at: "foo")) { error in
            if case .typeMismatch(_, let context) = error as? DecodingError {
                XCTAssertEqual(context.debugDescription, "Data found at 'foo' was not Int")
            } else {
                XCTFail("Catched error \"\(error)\", but not the expected: \"DecodingError.typeMismatch\"")
            }
        }
        XCTAssertThrowsError(try req.query.get(String.self, at: "bar")) { error in
            if case .valueNotFound(_, let context) = error as? DecodingError {
                XCTAssertEqual(context.debugDescription, "No String was found at 'bar'")
            } else {
                XCTFail("Catched error \"\(error)\", but not the expected: \"DecodingError.valueNotFound\"")
            }
        }

        XCTAssertEqual(req.query[String.self, at: "foo"], "a")
        XCTAssertEqual(req.query[String.self, at: "bar"], nil)

        //
        req = Request(method: .GET, url: .init(string: "/path"), on: EmbeddedEventLoop())
        XCTAssertThrowsError(try req.query.get(Int.self, at: "foo")) { error in
            if let error = error as? Abort {
                XCTAssertEqual(error.status, .unsupportedMediaType)
            } else {
                XCTFail("Catched error \"\(error)\", but not the expected: \"\(Abort(.unsupportedMediaType))\"")
            }
        }
        XCTAssertEqual(req.query[String.self, at: "foo"], nil)
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


        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/hello/vapor") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContains(res.body.string, "vapor")
        }.test(.POST, "/hello/vapor") { res in
            XCTAssertEqual(res.status, .notFound)
        }.test(.GET, "/hello/vapor/development") { res in
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

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/json") { res in
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

            let server = try app.testable().start()
            defer { server.shutdown() }

            try server.test(.GET, "/") { res in
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

            let server = try app.testable().start()
            defer { server.shutdown() }

            try server.test(.GET, "/") { res in
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

        let server = try app.testable().start()
        defer { server.shutdown() }
        
        try server.test(.GET, "/ping") { res in
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

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/todos?a=b") { res in
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

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/decode_error") { res in
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

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/encode") { res in
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

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/multipart", headers: [
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

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/multipart") { res in
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
            r.get("ws") { req -> EventLoopFuture<String> in
            let promise = req.eventLoop.makePromise(of: String.self)
                return WebSocket.connect(
                    to: "ws://echo.websocket.org/",
                    on: req.eventLoop
                ) { ws in
                    ws.send("Hello, world!")
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

        let server = try app.testable().start(method: .inMemory)
        defer { server.shutdown() }

        try server.test(.GET, "/ws") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        }
    }

    func testViewResponse() throws {
        var data = ByteBufferAllocator().buffer(capacity: 0)
        data.writeString("<h1>hello</h1>")
        let app = Application.create(routes: { r, c in
            let client = try c.make(Client.self)
            r.get("view") { req -> View in
                return View(data: data)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/view") { res in
            XCTAssertEqual(res.status.code, 200)
            XCTAssertEqual(res.headers.contentType, .html)
            XCTAssertEqual(res.body.string, "<h1>hello</h1>")
        }
    }

    func testURLEncodedFormDecode() throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = Application.create(routes: { r, c in
            r.get("urlencodedform") { req -> HTTPStatus in
                let foo = try req.content.decode(User.self)
                XCTAssertEqual(foo.name, "Vapor")
                XCTAssertEqual(foo.age, 3)
                XCTAssertEqual(foo.luckyNumbers, [5, 7])
                return .ok
            }
        })
        defer { app.shutdown() }

        var headers = HTTPHeaders()
        headers.contentType = .urlEncodedForm
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString("name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7")


        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/urlencodedform", headers: headers, body: body) { res in
            XCTAssertEqual(res.status.code, 200)
        }
    }

    func testURLEncodedFormEncode() throws {
        struct User: Content {
            static let defaultContentType: HTTPMediaType = .urlEncodedForm
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = Application.create(routes: { r, c in
            r.get("urlencodedform") { req -> User in
                return User(name: "Vapor", age: 3, luckyNumbers: [5, 7])
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/urlencodedform") { res in
            debugPrint(res)
            XCTAssertEqual(res.status.code, 200)
            XCTAssertEqual(res.headers.contentType, .urlEncodedForm)
            XCTAssertContains(res.body.string, "luckyNumbers[]=5")
            XCTAssertContains(res.body.string, "luckyNumbers[]=7")
            XCTAssertContains(res.body.string, "age=3")
            XCTAssertContains(res.body.string, "name=Vapor")
        }
    }

    func testURLEncodedFormDecodeQuery() throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = Application.create(routes: { r, c in
            r.get("urlencodedform") { req -> HTTPStatus in
                debugPrint(req)
                let foo = try req.query.decode(User.self)
                XCTAssertEqual(foo.name, "Vapor")
                XCTAssertEqual(foo.age, 3)
                XCTAssertEqual(foo.luckyNumbers, [5, 7])
                return .ok
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start(method: .inMemory)
        defer { server.shutdown() }

        let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7"
        try server.test(.GET, "/urlencodedform?\(data)") { res in
            XCTAssertEqual(res.status.code, 200)
        }
    }

    func testVaporURI() throws {
        do {
            var uri = URI(string: "http://vapor.codes/foo?bar=baz#qux")
            XCTAssertEqual(uri.scheme, "http")
            XCTAssertEqual(uri.host, "vapor.codes")
            XCTAssertEqual(uri.path, "/foo")
            XCTAssertEqual(uri.query, "bar=baz")
            XCTAssertEqual(uri.fragment, "qux")
            uri.query = "bar=baz&test=1"
            XCTAssertEqual(uri.string, "http://vapor.codes/foo?bar=baz&test=1#qux")
            uri.query = nil
            XCTAssertEqual(uri.string, "http://vapor.codes/foo#qux")
        }
        do {
            let uri = URI(string: "/foo/bar/baz")
            XCTAssertEqual(uri.path, "/foo/bar/baz")
        }
        do {
            let uri = URI(string: "ws://echo.websocket.org/")
            XCTAssertEqual(uri.scheme, "ws")
            XCTAssertEqual(uri.host, "echo.websocket.org")
            XCTAssertEqual(uri.path, "/")
        }
        do {
            let uri = URI(string: "http://foo")
            XCTAssertEqual(uri.scheme, "http")
            XCTAssertEqual(uri.host, "foo")
            XCTAssertEqual(uri.path, "")
        }
        do {
            let uri = URI(string: "foo")
            XCTAssertEqual(uri.scheme, "foo")
            XCTAssertEqual(uri.host, nil)
            XCTAssertEqual(uri.path, "")
        }
    }

    func testStreamFile() throws {
        let app = Application.create(routes: { r, c in
            let fileio = try c.make(FileIO.self)
            r.get("file-stream") { req -> Response in
                return fileio.streamFile(at: #file, for: req)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start(method: .running)
        defer { server.shutdown() }

        try server.test(.GET, "/file-stream") { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.firstValue(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileConnectionClose() throws {
        let app = Application.create(routes: { r, c in
            let fileio = try c.make(FileIO.self)
            r.get("file-stream") { req -> Response in
                return fileio.streamFile(at: #file, for: req)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start(method: .running)
        defer { server.shutdown() }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .connection, value: "close")

        try server.test(.GET, "/file-stream", headers: headers) { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.firstValue(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testCustomEncode() throws {
        let app = Application.create(routes: { r, c in
            r.get("custom-encode") { req -> Response in
                var res = Response(status: .ok)
                var jsonEncoder = JSONEncoder()
                jsonEncoder.outputFormatting = .prettyPrinted
                try res.content.encode(["hello": "world"], using: jsonEncoder)
                return res
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/custom-encode") { res in
            XCTAssertEqual(res.body.string, """
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
        let app = Application.create(routes: { r, c in
            r.post("decode-fail") { req -> String in
                let fail = try req.content.decode(DecodeFail.self)
                return "ok"
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"here":"hi"}"#)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
        headers.contentType = .json

        try server.test(.POST, "/decode-fail", headers: headers, body: body) { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(res.body.string, "missing")
        }
    }

    func testValidationError() throws {
        struct User: Content, Validatable {
            static func validations() -> Validations {
                var validations = Validations()
                validations.add("email", as: String.self, is: .email)
                return validations
            }

            var name: String
            var email: String
        }

        let app = Application.create(routes: { r, c in
            r.post("users") { req -> String in
                try User.validate(req)
                let user = try req.content.decode(User.self)
                return "ok"
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.POST, "/users", json: ["name": "vapor", "email": "foo"]) { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(res.body.string, "email is not a valid email address")
        }
    }

    func testAnyResponse() throws {
        let app = Application.create(routes: { r, c in
            r.get("foo") { req -> AnyResponse in
                if try req.query.get(String.self, at: "number") == "true" {
                    return AnyResponse(42)
                } else {
                    return AnyResponse("string")
                }
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/foo?number=true") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "42")
        }.test(.GET, "/foo?number=false") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "string")
        }
    }

    func testEnumResponse() throws {
        enum IntOrString: ResponseEncodable {
            case int(Int)
            case string(String)

            func encodeResponse(for req: Request) -> EventLoopFuture<Response> {
                switch self {
                case .int(let i):
                    return i.encodeResponse(for: req)
                case .string(let s):
                    return s.encodeResponse(for: req)
                }
            }
        }

        let app = Application.create(routes: { r, c in
            r.get("foo") { req -> IntOrString in
                if try req.query.get(String.self, at: "number") == "true" {
                    return .int(42)
                } else {
                    return .string("string")
                }
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/foo?number=true") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "42")
        }.test(.GET, "/foo?number=false") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "string")
        }
    }

    func testVaporProvider() throws {
        final class FooProvider: Provider {
            var registerFlag: Bool = false
            var willBootFlag: Bool = false
            var didBootFlag: Bool = false
            var willShutdownFlag: Bool = false

            func register(_ services: inout Services) {
                self.registerFlag = true
            }

            func willBoot(_ c: Container) -> EventLoopFuture<Void> {
                self.willBootFlag = true
                return c.eventLoop.makeSucceededFuture(())
            }

            func didBoot(_ c: Container) -> EventLoopFuture<Void> {
                self.didBootFlag = true
                return c.eventLoop.makeSucceededFuture(())
            }

            func willShutdown(_ c: Container) {
                self.willShutdownFlag = true
            }
        }
        let foo = FooProvider()

        XCTAssertEqual(foo.registerFlag, false)
        XCTAssertEqual(foo.willBootFlag, false)
        XCTAssertEqual(foo.didBootFlag, false)
        XCTAssertEqual(foo.willShutdownFlag, false)

        let app = Application.create(configure: { s in
            s.provider(foo)
            XCTAssertEqual(foo.registerFlag, true)
            XCTAssertEqual(foo.willBootFlag, false)
            XCTAssertEqual(foo.didBootFlag, false)
            XCTAssertEqual(foo.willShutdownFlag, false)
        }, routes: { r, c in
            // no routes
        })
        defer { app.shutdown() }

        let container = try app.makeContainer().wait()

        XCTAssertEqual(foo.registerFlag, true)
        XCTAssertEqual(foo.willBootFlag, true)
        XCTAssertEqual(foo.didBootFlag, true)
        XCTAssertEqual(foo.willShutdownFlag, false)

        container.shutdown()
        
        XCTAssertEqual(foo.registerFlag, true)
        XCTAssertEqual(foo.willBootFlag, true)
        XCTAssertEqual(foo.didBootFlag, true)
        XCTAssertEqual(foo.willShutdownFlag, true)
    }

    func testResponseEncodableStatus() throws {
        struct User: Content {
            var name: String
        }

        let app = Application.create(routes: { r, c in
            r.post("users") { req -> EventLoopFuture<Response> in
                return try req.content
                    .decode(User.self)
                    .encodeResponse(status: .created, for: req)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.POST, "/users", json: ["name": "vapor"]) { res in
            XCTAssertEqual(res.status, .created)
            XCTAssertEqual(res.headers.contentType, .json)
            XCTAssertEqual(res.body.string, """
            {"name":"vapor"}
            """)
        }
    }

    func testHeadRequest() throws {
        let app = Application.create(routes: { r, c in
            r.get("hello") { req -> String in
                XCTAssertEqual(req.method, .HEAD)
                return "hi"
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start(method: .running)
        defer { server.shutdown() }

        try server.test(.HEAD, "/hello") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.firstValue(name: .contentLength), "2")
            XCTAssertEqual(res.body.count, 0)
        }
    }

    func testInvalidCookie() throws {
        let app = Application.create(routes: { r, c in
            let sessions = try c.make(SessionsMiddleware.self)
            r.grouped(sessions).get("get") { req -> String in
                return req.session.data["name"] ?? "n/a"
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        var headers = HTTPHeaders()
        headers.cookie["vapor-session"] = "asdf"

        try server.test(.GET, "/get", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNotNil(res.headers[.setCookie])
            XCTAssertEqual(res.body.string, "n/a")
        }
    }

    func testMiddlewareOrder() throws {
        final class OrderMiddleware: Middleware {
            static var order: [String] = []
            let pos: String
            init(_ pos: String) {
                self.pos = pos
            }
            func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
                OrderMiddleware.order.append(pos)
                return next.respond(to: req)
            }
        }

        let app = Application.create(routes: { r, c in
            r.grouped(
                OrderMiddleware("a"), OrderMiddleware("b"), OrderMiddleware("c")
            ).get("order") { req -> String in
                return "done"
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/order") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(OrderMiddleware.order, ["a", "b", "c"])
            XCTAssertEqual(res.body.string, "done")
        }
    }

    func testSessionDestroy() throws {
        final class MockKeyedCache: Sessions {
            static var ops: [String] = []

            let eventLoop: EventLoop

            init(on eventLoop: EventLoop) {
                self.eventLoop = eventLoop
            }

            func createSession(_ data: SessionData) -> EventLoopFuture<SessionID> {
                Self.ops.append("create \(data)")
                return self.eventLoop.makeSucceededFuture(.init(string: "a"))
            }

            func readSession(_ sessionID: SessionID) -> EventLoopFuture<SessionData?> {
                Self.ops.append("read \(sessionID)")
                return self.eventLoop.makeSucceededFuture(SessionData())
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData) -> EventLoopFuture<SessionID> {
                Self.ops.append("update \(sessionID) to \(data)")
                return self.eventLoop.makeSucceededFuture(sessionID)
            }

            func deleteSession(_ sessionID: SessionID) -> EventLoopFuture<Void> {
                Self.ops.append("delete \(sessionID)")
                return self.eventLoop.makeSucceededFuture(())
            }
        }

        var cookie: HTTPCookies.Value?
        let app = Application.create(configure: { s in
            s.register(Sessions.self) { c in
                return MockKeyedCache(on: c.eventLoop)
            }
        }, routes: { r, c in
            let sessions = try r.grouped(c.make(SessionsMiddleware.self))
            sessions.get("set") { req -> String in
                req.session.data["foo"] = "bar"
                return "set"
            }
            sessions.get("del") { req  -> String in
                req.destroySession()
                return "del"
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/set") { res in
            XCTAssertEqual(res.body.string, "set")
            cookie = res.headers.setCookie["vapor-session"]
            XCTAssertNotNil(cookie)
            XCTAssertEqual(MockKeyedCache.ops, [
                #"create SessionData(storage: ["foo": "bar"])"#,
            ])
            MockKeyedCache.ops = []
        }

        XCTAssertEqual(cookie?.string, "a")

        var headers = HTTPHeaders()
        headers.cookie["vapor-session"] = cookie
        try server.test(.GET, "/del", headers: headers) { res in
            XCTAssertEqual(res.body.string, "del")
            XCTAssertEqual(MockKeyedCache.ops, [
                #"read SessionID(string: "a")"#,
                #"delete SessionID(string: "a")"#
            ])
        }
    }

    // https://github.com/vapor/vapor/issues/1687
    func testRequestQueryStringPercentEncoding() throws {
        struct TestQueryStringContainer: Content {
            var name: String
        }
        let req = Request(on: EmbeddedEventLoop())
        try req.query.encode(TestQueryStringContainer(name: "Vapor Test"))
        XCTAssertEqual(req.url.query, "name=Vapor%20Test")
    }

    // https://github.com/vapor/vapor/issues/1787
    func testGH1787() throws {
        let app = Application.create(routes: { r, c in
            r.get("no-content") { req -> String in
                throw Abort(.noContent)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start(method: .running)
        defer { server.shutdown() }

        try server.test(.GET, "/no-content") { res in
            XCTAssertEqual(res.status.code, 204)
            XCTAssertEqual(res.body.count, 0)
        }
    }

    // https://github.com/vapor/vapor/issues/1786
    func testMissingBody() throws {
        struct User: Content { }
        let app = Application.create(routes: { r, c in
            r.get("user") { req -> User in
                return try req.content.decode(User.self)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/user") { res in
            XCTAssertEqual(res.status, .unsupportedMediaType)
        }
    }

    func testSwiftError() throws {
        struct Foo: Error { }
        let app = Application.create(routes: { r, c in
            r.get("error") { req -> String in
                throw Foo()
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        try server.test(.GET, "/error") { res in
            XCTAssertEqual(res.status, .internalServerError)
        }
    }

    func testAsyncKitExport() throws {
        let eventLoop: EventLoop = EmbeddedEventLoop()
        let a = eventLoop.makePromise(of: Int.self)
        let b = eventLoop.makePromise(of: Int.self)

        let c = [a.futureResult, b.futureResult].flatten(on: eventLoop)

        a.succeed(1)
        b.succeed(2)

        try XCTAssertEqual(c.wait(), [1, 2])
    }

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

    // https://github.com/vapor/vapor/issues/1997
    func testWebSocket404() throws {
        let app = Application.create(routes: { r, c in
            r.webSocket("bar") { req, ws in
                ws.close(promise: nil)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start()
        defer { server.shutdown() }

        do {
            try WebSocket.connect(
                to: "ws://localhost:8085/foo",
                on: app.eventLoopGroup
            ) { _ in  }.wait()
            XCTFail("should have failed")
        } catch {
            // pass
        }
    }

    func testClientBeforeSend() throws {
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { try! client.syncShutdown() }

        let res = try client.post("http://httpbin.org/anything") { req in
            try req.content.encode(["hello": "world"])
        }.wait()

        struct HTTPBinAnything: Codable {
            var headers: [String: String]
            var json: [String: String]
        }
        let data = try res.content.decode(HTTPBinAnything.self)
        XCTAssertEqual(data.json, ["hello": "world"])
        XCTAssertEqual(data.headers["Content-Type"], "application/json; charset=utf-8")
    }

    func testSingletonServiceShutdown() throws {
        final class Foo {
            var didShutdown = false
        }
        struct Bar { }

        let app = Application.create(configure: { s in
            s.singleton(Foo.self, boot: { c in
                return Foo()
            }, shutdown: { foo in
                foo.didShutdown = true
            })
            // test normal singleton method
            s.singleton(Bar.self) { c in
                return .init()
            }
        }, routes: { (r, c) in
            // no routes
        })
        defer { app.shutdown() }

        let container = try app.makeContainer().wait()
        let foo = try container.make(Foo.self)
        XCTAssertEqual(foo.didShutdown, false)
        container.shutdown()
        XCTAssertEqual(foo.didShutdown, true)
    }

    // https://github.com/vapor/vapor/issues/2009
    func testWebSocketServer() throws {
        let app = Application.create(routes: { (r, c) in
            r.webSocket("foo") { req, ws in
                ws.send("foo")
                ws.close(promise: nil)
            }
        })
        defer { app.shutdown() }

        let server = try app.testable().start(method: .running(port: 8080))
        defer { server.shutdown() }

        let promise = app.eventLoopGroup.next().makePromise(of: String.self)
        WebSocket.connect(
            to: "ws://localhost:8080/foo",
            on: app.eventLoopGroup
        ) { ws in
            // do nothing
            ws.onText { ws, string in
                promise.succeed(string)
            }
        }.cascadeFailure(to: promise)

        try XCTAssertEqual(promise.futureResult.wait(), "foo")
    }

    func testPortOverride() throws {
        let env = Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--port", "8123"]
        )
        let app = Application.create(environment: env, routes: { (r, c) in
            r.get("foo") { req in
                return "bar"
            }
        })
        defer { app.shutdown() }
        try app.start()

        guard let running = app.running else {
            XCTFail("app started but didn't set running")
            return
        }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { try! client.syncShutdown() }

        let res = try client
            .get(url: "http://127.0.0.1:8123/foo")
            .wait()

        running.stop()
        try running.onStop.wait()

        XCTAssertEqual(res.body?.string, "bar")
    }
}

extension Application {
    static func create(
        environment: Environment = .testing,
        configure: @escaping (inout Services) -> () = { _ in },
        routes: @escaping (inout Routes, Container) throws -> () = { _, _ in }
    ) -> Application {
        let app = Application(environment: environment) { s in
            configure(&s)
            s.extend(Routes.self) { r, c in
                try routes(&r, c)
            }
        }
        try! app.boot()
        return app
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
