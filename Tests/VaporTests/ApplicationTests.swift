import Vapor
import XCTVapor
import COperatingSystem
import AsyncHTTPClient

final class ApplicationTests: XCTestCase {
    func testApplicationStop() throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = Application(test)
        defer { app.shutdown() }
        try app.start()
        guard let running = app.running else {
            XCTFail("app started without setting 'running'")
            return
        }
        running.stop()
        try running.onStop.wait()
    }

    func testContent() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(
            application: app,
            collectedBody: .init(string: #"{"hello": "world"}"#),
            on: EmbeddedEventLoop()
        )
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "hello"), "world")
    }

    func testComplexContent() throws {
        let app = Application()
        defer { app.shutdown() }

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
        let request = Request(
            application: app,
            collectedBody: .init(string: complexJSON),
            on: app.eventLoopGroup.next()
        )
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "batters", "batter", 1, "type"), "Chocolate")
    }

    func testQuery() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        request.headers.contentType = .json
        request.url.path = "/foo"
        request.url.query = "hello=world"
        try XCTAssertEqual(request.query.get(String.self, at: "hello"), "world")
    }

    func testQueryAsArray() throws {
        let app = Application()
        defer { app.shutdown() }
        
        let request = Request(application: app, on: app.eventLoopGroup.next())
        request.headers.contentType = .json
        request.url.path = "/foo"
        request.url.query = "hello=world&hello[]=you"
        try XCTAssertEqual(request.query.get([String].self, at: "hello"), ["world", "you"])
        try XCTAssertEqual(request.query.get([String].self, at: "goodbye"), [])
    }

    // https://github.com/vapor/vapor/pull/2163
    func testWrappedSingleValueQueryDecoding() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        request.headers.contentType = .json
        request.url.path = "/foo"
        request.url.query = ""
        
        // Think of property wrappers, or MongoKitten's ObjectId
        struct StringWrapper: Decodable {
            let string: String
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                string = try container.decode(String.self)
            }
        }
        
        XCTAssertThrowsError(try request.query.get(StringWrapper.self, at: "hello"))
    }
    
    func testNotCrashingArrayWithPercentEncoding() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        request.headers.contentType = .json
        request.url.path = "/"
        request.url.query = "emailsToSearch%5B%5D=xyz"
        let parsed = try request.query.get([String].self, at: "emailsToSearch[]")
        XCTAssertEqual(parsed, ["xyz"])
    }

    func testQueryGet() throws {
        let app = Application()
        defer { app.shutdown() }

        var req: Request

        //
        req = Request(
            application: app,
            method: .GET,
            url: .init(string: "/path?foo=a"),
            on: app.eventLoopGroup.next()
        )

        XCTAssertEqual(try req.query.get(String.self, at: "foo"), "a")
        XCTAssertThrowsError(try req.query.get(Int.self, at: "foo")) { error in
            if case .typeMismatch(_, let context) = error as? DecodingError {
                XCTAssertEqual(context.debugDescription, "Data found at 'foo' was not Int")
            } else {
                XCTFail("Caught error \"\(error)\", but not the expected: \"DecodingError.typeMismatch\"")
            }
        }
        XCTAssertThrowsError(try req.query.get(String.self, at: "bar")) { error in
            if case .valueNotFound(_, let context) = error as? DecodingError {
                XCTAssertEqual(context.debugDescription, "No String was found at 'bar'")
            } else {
                XCTFail("Caught error \"\(error)\", but not the expected: \"DecodingError.valueNotFound\"")
            }
        }

        XCTAssertEqual(req.query[String.self, at: "foo"], "a")
        XCTAssertEqual(req.query[String.self, at: "bar"], nil)

        //
        req = Request(
            application: app,
            method: .GET,
            url: .init(string: "/path"),
            on: app.eventLoopGroup.next()
        )
        XCTAssertThrowsError(try req.query.get(Int.self, at: "foo")) { error in
            if let error = error as? DecodingError {
                XCTAssertEqual(error.status, .badRequest)
            } else {
                XCTFail("Caught error \"\(error)\"")
            }
        }
        XCTAssertEqual(req.query[String.self, at: "foo"], nil)
    }

    func testParameter() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("hello", ":a") { req in
            return req.parameters.get("a") ?? ""
        }
        app.routes.get("hello", ":a", ":b") { req in
            return [req.parameters.get("a") ?? "", req.parameters.get("b") ?? ""]
        }
        try app.testable().test(.GET, "/hello/vapor") { res in
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
        let app = Application(.testing)
        defer { app.shutdown() }
                
        app.routes.get("json") { req -> [String: String] in
            print(req)
            return ["foo": "bar"]
        }

        try app.testable().test(.GET, "/json") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, #"{"foo":"bar"}"#)
        }
    }

    func testRootGet() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("") { req -> String in
                return "root"
        }
        app.routes.get("foo") { req -> String in
            return "foo"
        }

        try app.testable().test(.GET, "/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "root")
        }.test(.GET, "/foo") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "foo")
        }
    }
    
    func testLiveServer() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("ping") { req -> String in
            return "123"
        }
        
        try app.testable().test(.GET, "/ping") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "123")
        }
    }

    // https://github.com/vapor/vapor/issues/1537
    func testQueryStringRunning() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("todos") { req in
            return "hi"
        }

        try app.testable().test(.GET, "/todos?a=b") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "hi")
        }
    }

    func testGH1534() throws {
        let data = """
        {"name":"hi","bar":"asdf"}
        """
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("decode_error") { req -> String in
            struct Foo: Decodable {
                var name: String
                var bar: Int
            }
            let foo = try JSONDecoder().decode(Foo.self, from: Data(data.utf8))
            return foo.name
        }

        try app.testable().test(.GET, "/decode_error") { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("encode") { req -> Response in
            let res = Response()
            try res.content.encode(FooContent())
            try res.content.encode(FooContent(), as: .json)
            try res.content.encode(FooEncodable(), as: .json)
            return res
        }

        try app.testable().test(.GET, "/encode") { res in
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
        4\r
        --123\r
        Content-Disposition: form-data; name="image"; filename="droplet.png"\r
        \r
        <contents of image>\r
        --123--\r

        """
        let expected = User(
            name: "Vapor",
            age: 4,
            image: File(data: "<contents of image>", filename: "droplet.png")
        )

        struct User: Content, Equatable {
            var name: String
            var age: Int
            var image: File
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("multipart") { req -> User in
            let decoded = try req.content.decode(User.self)
            XCTAssertEqual(decoded, expected)
            return decoded
        }

        try app.testable().test(.GET, "/multipart", headers: [
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("multipart") { req -> User in
            return User(
                name: "Vapor",
                age: 4,
                image: File(data: "<contents of image>", filename: "droplet.png")
            )
        }
        try app.testable().test(.GET, "/multipart") { res in
            XCTAssertEqual(res.status, .ok)
            let boundary = res.headers.contentType?.parameters["boundary"] ?? "none"
            XCTAssertContains(res.body.string, "Content-Disposition: form-data; name=\"name\"")
            XCTAssertContains(res.body.string, "--\(boundary)")
            XCTAssertContains(res.body.string, "filename=\"droplet.png\"")
            XCTAssertContains(res.body.string, "name=\"image\"")
        }
    }

    func testWebSocketClient() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("ws") { req -> EventLoopFuture<String> in
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

        try app.testable().test(.GET, "/ws") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        }
    }

    func testViewResponse() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("view") { req -> View in
            var data = ByteBufferAllocator().buffer(capacity: 0)
            data.writeString("<h1>hello</h1>")
            return View(data: data)
        }

        try app.testable().test(.GET, "/view") { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("urlencodedform") { req -> HTTPStatus in
            let foo = try req.content.decode(User.self)
            XCTAssertEqual(foo.name, "Vapor")
            XCTAssertEqual(foo.age, 3)
            XCTAssertEqual(foo.luckyNumbers, [5, 7])
            return .ok
        }

        var headers = HTTPHeaders()
        headers.contentType = .urlEncodedForm
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString("name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7")

        try app.testable().test(.GET, "/urlencodedform", headers: headers, body: body) { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("urlencodedform") { req -> User in
            return User(name: "Vapor", age: 3, luckyNumbers: [5, 7])
        }
        try app.testable().test(.GET, "/urlencodedform") { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("urlencodedform") { req -> HTTPStatus in
            debugPrint(req)
            let foo = try req.query.decode(User.self)
            XCTAssertEqual(foo.name, "Vapor")
            XCTAssertEqual(foo.age, 3)
            XCTAssertEqual(foo.luckyNumbers, [5, 7])
            return .ok
        }

        let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7"
        try app.testable().test(.GET, "/urlencodedform?\(data)") { res in
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
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file)
        }

        try app.testable(method: .running).test(.GET, "/file-stream") { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.firstValue(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testStreamFileConnectionClose() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
 
        app.get("file-stream") { req in
            return req.fileio.streamFile(at: #file)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .connection, value: "close")
        try app.testable(method: .running).test(.GET, "/file-stream", headers: headers) { res in
            let test = "the quick brown fox"
            XCTAssertNotNil(res.headers.firstValue(name: .eTag))
            XCTAssertContains(res.body.string, test)
        }
    }

    func testCustomEncode() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("custom-encode") { req -> Response in
            let res = Response(status: .ok)
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .prettyPrinted
            try res.content.encode(["hello": "world"], using: jsonEncoder)
            return res
        }

        try app.testable().test(.GET, "/custom-encode") { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.post("decode-fail") { req -> String in
            _ = try req.content.decode(DecodeFail.self)
            return "ok"
        }

        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"here":"hi"}"#)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
        headers.contentType = .json

        try app.testable().test(.POST, "/decode-fail", headers: headers, body: body) { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(res.body.string, "missing")
        }
    }

    func testValidationError() throws {
        struct User: Content, Validatable {
            static func validations(_ v: inout Validations) {
                v.add("email", is: .email)
            }

            var name: String
            var email: String
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.post("users") { req -> User in
            try User.validate(req)
            return try req.content.decode(User.self)
        }

        try app.testable().test(.POST, "/users", beforeRequest: { req in
            try req.content.encode([
                "name": "vapor",
                "email": "foo"
            ], as: .json)
        }) { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(res.body.string, "email is not a valid email address")
        }
    }

    func testAnyResponse() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("foo") { req -> AnyResponse in
            if try req.query.get(String.self, at: "number") == "true" {
                return AnyResponse(42)
            } else {
                return AnyResponse("string")
            }
        }

        try app.testable().test(.GET, "/foo", beforeRequest: { req in
            try req.query.encode(["number": "true"])
        }) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "42")
        }.test(.GET, "/foo", beforeRequest: { req in
            try req.query.encode(["number": "false"])
        }) { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.get("foo") { req -> IntOrString in
            if try req.query.get(String.self, at: "number") == "true" {
                return .int(42)
            } else {
                return .string("string")
            }
        }

        try app.testable().test(.GET, "/foo?number=true") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "42")
        }.test(.GET, "/foo?number=false") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "string")
        }
    }

    func testVaporLifecycleHandler() throws {
        final class Foo: LifecycleHandler {
            var willBootFlag: Bool
            var didBootFlag: Bool
            var shutdownFlag: Bool

            init() {
                self.willBootFlag = false
                self.didBootFlag = false
                self.shutdownFlag = false
            }

            func willBoot(_ application: Application) throws {
                self.willBootFlag = true
            }

            func didBoot(_ application: Application) throws {
                self.didBootFlag = true
            }

            func shutdown(_ application: Application) {
                self.shutdownFlag = true
            }
        }
        
        let app = Application(.testing)

        let foo = Foo()
        app.lifecycle.use(foo)

        XCTAssertEqual(foo.willBootFlag, false)
        XCTAssertEqual(foo.didBootFlag, false)
        XCTAssertEqual(foo.shutdownFlag, false)

        try app.boot()

        XCTAssertEqual(foo.willBootFlag, true)
        XCTAssertEqual(foo.didBootFlag, true)
        XCTAssertEqual(foo.shutdownFlag, false)

        app.shutdown()

        XCTAssertEqual(foo.willBootFlag, true)
        XCTAssertEqual(foo.didBootFlag, true)
        XCTAssertEqual(foo.shutdownFlag, true)
    }

    func testResponseEncodableStatus() throws {
        struct User: Content {
            var name: String
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.post("users") { req -> EventLoopFuture<Response> in
            return try req.content
                .decode(User.self)
                .encodeResponse(status: .created, for: req)
        }

        try app.testable().test(.POST, "/users", beforeRequest: { req in
            try req.content.encode(["name": "vapor"], as: .json)
        }) { res in
            XCTAssertEqual(res.status, .created)
            XCTAssertEqual(res.headers.contentType, .json)
            XCTAssertEqual(res.body.string, """
            {"name":"vapor"}
            """)
        }
    }

    func testHeadRequest() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("hello") { req -> String in
            XCTAssertEqual(req.method, .HEAD)
            return "hi"
        }

        try app.testable(method: .running).test(.HEAD, "/hello") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.firstValue(name: .contentLength), "2")
            XCTAssertEqual(res.body.readableBytes, 0)
        }
    }

    func testInvalidCookie() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.grouped(SessionsMiddleware(session: app.sessions.driver))
            .get("get") { req -> String in
                return req.session.data["name"] ?? "n/a"
            }

        var headers = HTTPHeaders()
        headers.cookie["vapor-session"] = "asdf"
        try app.testable().test(.GET, "/get", headers: headers) { res in
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
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.grouped(
            OrderMiddleware("a"), OrderMiddleware("b"), OrderMiddleware("c")
        ).get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(OrderMiddleware.order, ["a", "b", "c"])
            XCTAssertEqual(res.body.string, "done")
        }
    }

    func testSessionDestroy() throws {
        final class MockKeyedCache: SessionDriver {
            static var ops: [String] = []
            init() { }


            func createSession(_ data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
                Self.ops.append("create \(data)")
                return request.eventLoop.makeSucceededFuture(.init(string: "a"))
            }

            func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<SessionData?> {
                Self.ops.append("read \(sessionID)")
                return request.eventLoop.makeSucceededFuture(SessionData())
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
                Self.ops.append("update \(sessionID) to \(data)")
                return request.eventLoop.makeSucceededFuture(sessionID)
            }

            func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
                Self.ops.append("delete \(sessionID)")
                return request.eventLoop.makeSucceededFuture(())
            }
        }

        var cookie: HTTPCookies.Value?

        let app = Application()
        defer { app.shutdown() }
        
        let cache = MockKeyedCache()
        app.sessions.use { _ in cache }
        let sessions = app.routes.grouped(SessionsMiddleware(session: app.sessions.driver))
        sessions.get("set") { req -> String in
            req.session.data["foo"] = "bar"
            return "set"
        }
        sessions.get("del") { req  -> String in
            req.destroySession()
            return "del"
        }

        try app.testable().test(.GET, "/set") { res in
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
        try app.testable().test(.GET, "/del", headers: headers) { res in
            XCTAssertEqual(res.body.string, "del")
            XCTAssertEqual(MockKeyedCache.ops, [
                #"read SessionID(string: "a")"#,
                #"delete SessionID(string: "a")"#
            ])
        }
    }

    // https://github.com/vapor/vapor/issues/1687
    func testRequestQueryStringPercentEncoding() throws {
        let app = Application()
        defer { app.shutdown() }

        struct TestQueryStringContainer: Content {
            var name: String
        }
        let req = Request(application: app, on: app.eventLoopGroup.next())
        try req.query.encode(TestQueryStringContainer(name: "Vapor Test"))
        XCTAssertEqual(req.url.query, "name=Vapor%20Test")
    }

    // https://github.com/vapor/vapor/issues/1787
    func testGH1787() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("no-content") { req -> String in
            throw Abort(.noContent)
        }

        try app.testable(method: .running).test(.GET, "/no-content") { res in
            XCTAssertEqual(res.status.code, 204)
            XCTAssertEqual(res.body.readableBytes, 0)
        }
    }

    // https://github.com/vapor/vapor/issues/1786
    func testMissingBody() throws {
        struct User: Content { }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("user") { req -> User in
            return try req.content.decode(User.self)
        }

        try app.testable().test(.GET, "/user") { res in
            XCTAssertEqual(res.status, .unsupportedMediaType)
        }
    }

    func testSwiftError() throws {
        struct Foo: Error { }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("error") { req -> String in
            throw Foo()
        }

        try app.testable().test(.GET, "/error") { res in
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
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.server.configuration.port = 8085
        
        app.webSocket("bar") { req, ws in
            ws.close(promise: nil)
        }

        try app.start()

        do {
            try WebSocket.connect(
                to: "ws://localhost:8085/foo",
                on: app.eventLoopGroup.next()
            ) { _ in  }.wait()
            XCTFail("should have failed")
        } catch {
            // pass
        }
    }

    func testClientBeforeSend() throws {
        let app = Application()
        defer { app.shutdown() }
        try app.boot()
        
        let res = try app.client.post("http://httpbin.org/anything") { req in
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

//    func testSingletonServiceShutdown() throws {
//        final class Foo {
//            var didShutdown = false
//        }
//        struct Bar { }
//
//        let app = Application(environment: .testing)
//        app.register(singleton: Foo.self, boot: { c in
//            return Foo()
//        }, shutdown: { foo in
//            foo.didShutdown = true
//        })
//        // test normal singleton method
//        app.register(Bar.self) { c in
//            return .init()
//        }
//
//        let foo = app.make(Foo.self)
//        XCTAssertEqual(foo.didShutdown, false)
//        app.shutdown()
//        XCTAssertEqual(foo.didShutdown, true)
//    }

    // https://github.com/vapor/vapor/issues/2009
    func testWebSocketServer() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.webSocket("foo") { req, ws in
            ws.send("foo")
            ws.close(promise: nil)
        }

        try app.start()
        let promise = app.eventLoopGroup.next().makePromise(of: String.self)
        WebSocket.connect(
            to: "ws://localhost:8080/foo",
            on: app.eventLoopGroup.next()
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
        
        let app = Application(env)
        defer { app.shutdown() }
        
        app.get("foo") { req in
            return "bar"
        }
        try app.start()

        let res = try app.client.get("http://127.0.0.1:8123/foo").wait()
        XCTAssertEqual(res.body?.string, "bar")
    }

    func testBoilerplateClient() throws {
        let app = Application(.init(
            name: "xctest",
            arguments: ["vapor", "serve", "-b", "localhost:8080", "--log", "trace"]
        ))
        try LoggingSystem.bootstrap(from: &app.environment)
        defer { app.shutdown() }

        app.get("foo") { req -> EventLoopFuture<String> in
            return req.client.get("https://httpbin.org/status/201").map { res in
                XCTAssertEqual(res.status.code, 201)
                req.application.running?.stop()
                return "bar"
            }.flatMapErrorThrowing {
                req.application.running?.stop()
                throw $0
            }
        }

        try app.boot()
        try app.start()

        let res = try app.client.get("http://localhost:8080/foo").wait()
        XCTAssertEqual(res.body?.string, "bar")

        try app.running?.onStop.wait()
    }

    func testBoilerplate() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("hello") { req in
            "Hello, world!"
        }

        try app.start()

        let res = try app.client.get("http://localhost:8080/hello").wait()
        XCTAssertEqual(res.body?.string, "Hello, world!")
    }

    func testChangeRequestLogLevel() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("trace") { req -> String in
            req.logger.logLevel = .trace
            req.logger.trace("foo")
            return "done"
        }

        try app.testable().test(.GET, "trace") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "done")
        }
    }
    
    func testTestWithJsonPreservesHTTPHeaders() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("check") { (req: Request) -> String in
            return "\(req.headers.firstValue(name: .init("X-Test-Value")) ?? "MISSING").\(req.headers.firstValue(name: .contentType) ?? "?")"
        }
        
        try app.testable().test(.GET, "/check", headers: ["X-Test-Value": "PRESENT"], beforeRequest: { req in
            try req.content.encode(["foo": "bar"], as: .json)
        }) { res in
            XCTAssertEqual(res.body.string, "PRESENT.application/json; charset=utf-8")
        }
    }
    
    func testTestWithJsonAllowsContentTypeOverride() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("check") { (req: Request) -> String in
            return "\(req.headers.firstValue(name: .init("X-Test-Value")) ?? "MISSING").\(req.headers.firstValue(name: .contentType) ?? "?")"
        }
        // Me and my sadistic sense of humor.
        ContentConfiguration.global.use(decoder: try! ContentConfiguration.global.requireDecoder(for: .json), for: .xml)
        
        try app.testable().test(.GET, "/check", headers: [
            "X-Test-Value": "PRESENT"
        ], beforeRequest: { req in
            try req.content.encode(["foo": "bar"], as: .json)
            req.headers.contentType = .xml
        }) { res in
            XCTAssertEqual(res.body.string, "PRESENT.application/xml; charset=utf-8")
        }
    }

    func testApplicationClientThreadSafety() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let startingPistol = DispatchGroup()
        startingPistol.enter()
        startingPistol.enter()

        let finishLine = DispatchGroup()
        finishLine.enter()
        Thread.async {
            startingPistol.leave()
            startingPistol.wait()
            XCTAssert(type(of: app.client.http) == HTTPClient.self)
            finishLine.leave()
        }

        finishLine.enter()
        Thread.async {
            startingPistol.leave()
            startingPistol.wait()
            XCTAssert(type(of: app.client.http) == HTTPClient.self)
            finishLine.leave()
        }

        finishLine.wait()
    }

    func testRequestRemoteAddress() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("remote") {
            $0.remoteAddress?.description ?? "n/a"
        }

        try app.testable(method: .running).test(.GET, "remote") { res in
            XCTAssertContains(res.body.string, "IP")
        }
    }

    func testClientConfigurationChange() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.client.configuration.redirectConfiguration = .disallow

        app.get("redirect") {
            $0.redirect(to: "foo")
        }

        let server = try app.server.start(hostname: "localhost", port: 8080)
        defer { server.shutdown() }

        let res = try app.client.get("http://localhost:8080/redirect").wait()

        XCTAssertEqual(res.status, .seeOther)
    }

    func testClientResponseCodable() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let res = try app.client.get("https://httpbin.org/json").wait()

        let encoded = try JSONEncoder().encode(res)
        let decoded = try JSONDecoder().decode(ClientResponse.self, from: encoded)
        
        XCTAssertEqual(res, decoded)
    }
    
    func testMultipleChunkBody() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let payload = [UInt8].random(count: 1 << 20)
        
        app.post("payload") { req -> HTTPStatus in
            guard let data = req.body.data else {
                throw Abort(.internalServerError)
            }
            XCTAssertEqual(payload.count, data.readableBytes)
            XCTAssertEqual([UInt8](data.readableBytesView), payload)
            return .ok
        }
        
        var buffer = ByteBufferAllocator().buffer(capacity: payload.count)
        buffer.writeBytes(payload)
        try app.testable(method: .running).test(.POST, "payload", body: buffer) { res in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testEndpointCacheNoCache() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        var current = 0
        struct Test: Content {
            let number: Int
        }

        app.get("number") { req -> Test in
            defer { current += 1 }
            return Test(number: current)
        }

        let cache = EndpointCache<Test>(uri: "/number")
        do {
            let test = try cache.get(
                using: app.responder.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        do {
            let test = try cache.get(
                using: app.responder.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 1)
        }
    }

    func testEndpointCacheMaxAge() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        var current = 0
        struct Test: Content {
            let number: Int
        }

        app.get("number") { req -> Response in
            defer { current += 1 }
            let res = Response()
            try res.content.encode(Test(number: current))
            res.headers.cacheControl = .init(maxAge: 1)
            return res
        }

        let cache = EndpointCache<Test>(uri: "/number")
        do {
            let test = try cache.get(
                using: app.responder.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        do {
            let test = try cache.get(
                using: app.responder.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 0)
        }
        // wait for expiry
        sleep(1)
        do {
            let test = try cache.get(
                using: app.responder.client,
                logger: app.logger,
                on: app.eventLoopGroup.next()
            ).wait()
            XCTAssertEqual(test.number, 1)
        }
    }

    func testHexEncoding() throws {
        let bytes: [UInt8] = [1, 42, 128, 240]
        XCTAssertEqual(bytes.hex, "012a80f0")
        XCTAssertEqual(bytes.hexEncodedString(), "012a80f0")
        XCTAssertEqual(bytes.hexEncodedString(uppercase: true), "012A80F0")
    }
    
    func testConfigureHTTPDecompressionLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let smallOrigString = "Hello, world!"
        let smallBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11Eozy/KSVEEAObG5usNAAA=")! // "Hello, world!"
        let bigBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11HILU3OgBBJmenpqUUK5flFOSkKJRmJeQpJqWn5RamKAICcGhUqAAAA")! // "Hello, much much bigger world than before!"

        // Max out at the smaller payload (.size is of compressed data)
        app.server.configuration.requestDecompression = .enabled(
            limit: .size(smallBody.readableBytes)
        )
        app.post("gzip") { $0.body.string ?? "" }

        let server = try app.server.start()
        defer { server.shutdown() }

        // Small payload should just barely get through.
        let res = try app.client.post("http://localhost:8080/gzip") { req in
            req.headers.replaceOrAdd(name: .contentEncoding, value: "gzip")
            req.body = smallBody
        }.wait()
        XCTAssertEqual(res.body?.string, smallOrigString)
        
        // Big payload should be hard-rejected. We can't test for the raw NIOHTTPDecompression.DecompressionError.limit error here because
        // protocol decoding errors are only ever logged and can't be directly caught.
        do {
            _ = try app.client.post("http://localhost:8080/gzip") { req in
                req.headers.replaceOrAdd(name: .contentEncoding, value: "gzip")
                req.body = bigBody
            }.wait()
        } catch let error as HTTPClientError {
            XCTAssertEqual(error, HTTPClientError.remoteConnectionClosed)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testBase32() throws {
        let data = Data([1, 2, 3, 4])
        XCTAssertEqual(data.base32EncodedString(), "AEBAGBA")
        XCTAssertEqual(Data(base32Encoded: "AEBAGBA"), data)

    }
}

extension Application.Responder {
    /// Creates a `Client` from an `Application`'s  current`Responder`.
    var client: Client {
        ResponderClient(responder: self.current, application: self.application)
    }
}

struct ResponderClient: Client {
    let responder: Responder
    let application: Application

    var eventLoopGroup: EventLoopGroup {
        self.application.eventLoopGroup
    }

    func `for`(_ request: Request) -> Client {
        self
    }


    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        self.responder.respond(to: .init(
            application: self.application,
            method: request.method,
            url: request.url,
            version: .init(major: 1, minor: 1),
            headersNoUpdate: request.headers,
            collectedBody: request.body,
            remoteAddress: nil,
            logger: application.logger,
            on: application.eventLoopGroup.next()
        )).map { res in
            ClientResponse(status: res.status, headers: res.headers, body: res.body.buffer)
        }
    }


}

private extension ByteBuffer {
    init(string: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString(string)
        self = buffer
    }
    
    init?(base64String: String) {
        guard let decoded = Data(base64Encoded: base64String) else { return nil }
        var buffer = ByteBufferAllocator().buffer(capacity: decoded.count)
        buffer.writeBytes(decoded)
        self = buffer
    }
}
