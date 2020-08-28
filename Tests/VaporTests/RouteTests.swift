import XCTVapor

final class RouteTests: XCTestCase {
    func testParameter() throws {
        let app = Application(.detect(default: .testing))
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

    func testRequiredParameter() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.routes.get("string", ":value") { req in
            return try req.parameters.require("value")
        }

        app.routes.get("int", ":value") { req -> String in
            let value = try req.parameters.require("value", as: Int.self)
            return String(value)
        }

        app.routes.get("missing") { req in
            return try req.parameters.require("value")
        }

        try app.testable().test(.GET, "/string/test") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContains(res.body.string, "test")
        }.test(.GET, "/int/123") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "123")
        }.test(.GET, "/int/not-int") { res in
            XCTAssertEqual(res.status, .unprocessableEntity)
        }.test(.GET, "/missing") { res in
            XCTAssertEqual(res.status, .internalServerError)
        }
    }

    func testJSON() throws {
        let app = Application(.detect(default: .testing))
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
        let app = Application(.detect(default: .testing))
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
    
    func testInsensitiveRoutes() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }
        
        app.routes.caseInsensitive = true
        
        app.routes.get("foo") { req -> String in
            return "foo"
        }

        try app.testable().test(.GET, "/foo") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "foo")
        }.test(.GET, "/FOO") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "foo")
        }
    }

    func testAnyResponse() throws {
        let app = Application(.detect(default: .testing))
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

        let app = Application(.detect(default: .testing))
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

    func testValidationError() throws {
        struct User: Content, Validatable {
            static func validations(_ v: inout Validations) {
                v.add("email", is: .email)
            }

            var name: String
            var email: String
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.post("users") { req -> User in
            try User.validate(content: req)
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

    func testResponseEncodableStatus() throws {
        struct User: Content {
            var name: String
        }

        let app = Application(.detect(default: .testing))
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
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("hello") { req -> String in
            XCTAssertEqual(req.method, .HEAD)
            return "hi"
        }

        try app.testable(method: .running).test(.HEAD, "/hello") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .contentLength), "2")
            XCTAssertEqual(res.body.readableBytes, 0)
        }
    }

    func testInvalidCookie() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.grouped(SessionsMiddleware(session: app.sessions.driver))
            .get("get") { req -> String in
                return req.session.data["name"] ?? "n/a"
            }

        var headers = HTTPHeaders()
        var cookies = HTTPCookies()
        cookies["vapor-session"] = "asdf"
        headers.cookie = cookies
        try app.testable().test(.GET, "/get", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNotNil(res.headers[.setCookie])
            XCTAssertEqual(res.body.string, "n/a")
        }
    }

    // https://github.com/vapor/vapor/issues/1787
    func testGH1787() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("no-content") { req -> String in
            throw Abort(.noContent)
        }

        try app.testable(method: .running).test(.GET, "/no-content") { res in
            XCTAssertEqual(res.status.code, 204)
            XCTAssertEqual(res.body.readableBytes, 0)
        }
    }

    func testSimilarRoutingPath() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("api","addresses") { req in
            "a"
        }
        app.get("api", "addresses","search", ":id") { req in
            "b"
        }

        try app.testable(method: .running).test(.GET, "/api/addresses/") { res in
            XCTAssertEqual(res.body.string, "a")
        }.test(.GET, "/api/addresses/search/test") { res in
            XCTAssertEqual(res.body.string, "b")
        }.test(.GET, "/api/addresses/search/") { res in
            XCTAssertEqual(res.status, .notFound)
        }.test(.GET, "/api/addresses/search") { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testThrowingGroup() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        XCTAssertThrowsError(try app.routes.group("foo") { router in
            throw Abort(.internalServerError, reason: "Test")
        })
    }

    func testCollection() throws {
        struct Foo: RouteCollection {
            func boot(routes: RoutesBuilder) throws {
                routes.get("foo") { _ in "bar" }
            }
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }
        try app.register(collection: Foo())

        try app.test(.GET, "foo") { res in
            XCTAssertEqual(res.body.string, "bar")
        }
    }

    func testConfigurableMaxBodySize() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        XCTAssertEqual(app.routes.defaultMaxBodySize, 16384)
        app.routes.defaultMaxBodySize = 1
        XCTAssertEqual(app.routes.defaultMaxBodySize, 1)

        app.on(.POST, "default") { request in
            HTTPStatus.ok
        }
        app.on(.POST, "1kb", body: .collect(maxSize: "1kb")) { request in
            HTTPStatus.ok
        }
        app.on(.POST, "1mb", body: .collect(maxSize: "1mb")) { request in
            HTTPStatus.ok
        }
        app.on(.POST, "1gb", body: .collect(maxSize: "1gb")) { request in
            HTTPStatus.ok
        }

        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeBytes(Array(repeating: 0, count: 500_000))
        try app.testable(method: .running).test(.POST, "/default", body: buffer) { res in
            XCTAssertEqual(res.status, .payloadTooLarge)
        }.test(.POST, "/1kb", body: buffer) { res in
            XCTAssertEqual(res.status, .payloadTooLarge)
        }.test(.POST, "/1mb", body: buffer) { res in
            XCTAssertEqual(res.status, .ok)
        }.test(.POST, "/1gb", body: buffer) { res in
            XCTAssertEqual(res.status, .ok)
        }
    }
}
