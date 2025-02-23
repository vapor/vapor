import NIOCore
import Testing
import VaporTesting
import Vapor
import NIOHTTP1
import WebSocketKit

@Suite("Route Tests")
struct RouteTests {
    @Test("Test Parameter")
    func testParameter() async throws {
        try await withApp { app in
            app.routes.get("hello", ":a") { req in
                return req.parameters.get("a") ?? ""
            }
            app.routes.get("hello", ":a", ":b") { req in
                return [req.parameters.get("a") ?? "", req.parameters.get("b") ?? ""]
            }
            try await app.testing().test(.GET, "/hello/vapor") { res in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("vapor"))
            }.test(.POST, "/hello/vapor") { res in
                #expect(res.status == .notFound)
            }.test(.GET, "/hello/vapor/development") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == #"["vapor","development"]"#)
            }
        }
    }

    @Test("Test Required Parameter")
    func testRequiredParameter() async throws {
        try await withApp { app in
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

            try await app.testing().test(.GET, "/string/test") { res in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("test"))
            }.test(.GET, "/int/123") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "123")
            }.test(.GET, "/int/not-int") { res in
                #expect(res.status == .unprocessableEntity)
            }.test(.GET, "/missing") { res in
                #expect(res.status == .internalServerError)
            }
        }
    }

    @Test("Test JSON")
    func testJSON() async throws {
        try await withApp { app in
            app.routes.get("json") { req -> [String: String] in
                return ["foo": "bar"]
            }

            try await app.testing().test(.GET, "/json") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == #"{"foo":"bar"}"#)
            }
        }
    }

    @Test("Test Root Get")
    func testRootGet() async throws {
        try await withApp { app in
            app.routes.get("") { req -> String in
                return "root"
            }
            app.routes.get("foo") { req -> String in
                return "foo"
            }

            try await app.testing().test(.GET, "/") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "root")
            }.test(.GET, "/foo") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foo")
            }
        }
    }

    @Test("Test Insensitive Routes")
    func testInsensitiveRoutes() async throws {
        try await withApp { app in
            app.routes.caseInsensitive = true

            app.routes.get("foo") { req -> String in
                return "foo"
            }

            try await app.testing().test(.GET, "/foo") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foo")
            }.test(.GET, "/FOO") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foo")
            }
        }
    }

    @Test("Test AnyResponse")
    func testAnyResponse() async throws {
        try await withApp { app in
            app.get("foo") { req -> AnyResponse in
                if try req.query.get(String.self, at: "number") == "true" {
                    return AnyResponse(42)
                } else {
                    return AnyResponse("string")
                }
            }

            try await app.testing().test(.GET, "/foo", beforeRequest: { req in
                try req.query.encode(["number": "true"])
            }) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "42")
            }.test(.GET, "/foo", beforeRequest: { req in
                try req.query.encode(["number": "false"])
            }) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "string")
            }
        }
    }

    @Test("Test Enum Response")
    func testEnumResponse() async throws {
        enum IntOrString: AsyncResponseEncodable {
            case int(Int)
            case string(String)

            func encodeResponse(for request: Request) async throws -> Response {
                switch self {
                case .int(let i):
                    return try await i.encodeResponse(for: request)
                case .string(let s):
                    return try await s.encodeResponse(for: request)
                }
            }
        }

        try await withApp { app in
            app.routes.get("foo") { req -> IntOrString in
                if try req.query.get(String.self, at: "number") == "true" {
                    return .int(42)
                } else {
                    return .string("string")
                }
            }

            try await app.testing().test(.GET, "/foo?number=true") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "42")
            }.test(.GET, "/foo?number=false") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "string")
            }
        }
    }

    @Test("Test Validation Error")
    func testValidationError() async throws {
        struct User: Content, Validatable {
            static func validations(_ v: inout Validations) {
                v.add("email", is: .email)
            }

            var name: String
            var email: String
        }

        try await withApp { app in
            app.post("users") { req -> User in
                try User.validate(content: req)
                return try req.content.decode(User.self)
            }

            try await app.testing().test(.POST, "/users", beforeRequest: { req in
                try req.content.encode([
                    "name": "vapor",
                    "email": "foo"
                ], as: .json)
            }) { res in
                #expect(res.status == .badRequest)
                #expect(res.body.string.contains("email is not a valid email address"))
            }.test(.POST, "/users") { res in
                #expect(res.status == .unprocessableEntity)
                #expect(res.body.string.replacingOccurrences(of: "\\", with: "").contains("Missing \"Content-Type\" header"))
            }.test(.POST, "/users", headers: ["Content-Type":"application/json"]) { res in
                #expect(res.status == .unprocessableEntity)
                #expect(res.body.string.contains("Empty Body"))
            }
        }
    }

    @Test("Test Response Encodable Status")
    func testResponseEncodableStatus() async throws {
        struct User: Content {
            var name: String
        }

        try await withApp { app in
            app.post("users") { req async throws -> Response in
                return try await req.content
                    .decode(User.self)
                    .encodeResponse(status: .created, for: req)
            }

            try await app.testing().test(.POST, "/users", beforeRequest: { req async throws in
                try req.content.encode(["name": "vapor"], as: .json)
            }) { res in
                #expect(res.status == .created)
                #expect(res.headers.contentType == .json)
                #expect(res.body.string == """
            {"name":"vapor"}
            """)
            }
        }
    }

    @Test("Test Head Request Forwarded to Get")
    func testHeadRequestForwardedToGet() async throws {
        try await withApp { app in
            app.get("hello") { req -> String in
                #expect(req.method == .HEAD)
                return "hi"
            }

            try await app.testing(method: .running(port: 0)).test(.HEAD, "/hello") { res in
                #expect(res.status == .ok)
                #expect(res.headers.first(name: .contentLength) == "2")
                #expect(res.body.readableBytes == 0)
            }
        }
    }

    @Test("Test Explicit Head Route Overrides Forwarding to Get")
    func testExplicitHeadRouteOverridesForwardingToGet() async throws {
        try await withApp { app in
            app.get("hello") { req -> Response in
                return Response(status: .badRequest)
            }

            app.on(.HEAD, "hello") { req -> Response in
                return Response(status: .found)
            }

            try await app.testing(method: .running(port: 0)).test(.HEAD, "/hello") { res in
                #expect(res.status == .found)
                #expect(res.headers.first(name: .contentLength) == "0")
                #expect(res.body.readableBytes == 0)
            }
        }
    }

    @Test("Test Invalid Cookie")
    func testInvalidCookie() async throws {
        try await withApp { app in
            app.grouped(SessionsMiddleware(session: app.sessions.driver))
                .get("get") { req -> String in
                    return req.session.data["name"] ?? "n/a"
                }

            var headers = HTTPHeaders()
            var cookies = HTTPCookies()
            cookies["vapor-session"] = "asdf"
            headers.cookie = cookies
            try await app.testing().test(.GET, "/get", headers: headers) { res in
                #expect(res.status == .ok)
                #expect(res.headers[.setCookie].first != nil)
                #expect(res.body.string == "n/a")
            }
        }
    }

    @Test("Test Throwing .noContent Does Not Close Connection", .bug("https://github.com/vapor/vapor/issues/1787"))
    func testGH1787() async throws {
        try await withApp { app in
            app.get("no-content") { req -> String in
                throw Abort(.noContent)
            }

            try await app.testing(method: .running(port: 0)).test(.GET, "/no-content") { res in
                #expect(res.status.code == 204)
                #expect(res.body.readableBytes == 0)
            }
        }
    }

    @Test("Test Similar Routing Path")
    func testSimilarRoutingPath() async throws {
        try await withApp { app in
            app.get("api","addresses") { req in
                "a"
            }
            app.get("api", "addresses","search", ":id") { req in
                "b"
            }

            try await app.testing(method: .running(port: 0)).test(.GET, "/api/addresses/") { res in
                #expect(res.body.string == "a")
            }.test(.GET, "/api/addresses/search/test") { res in
                #expect(res.body.string == "b")
            }.test(.GET, "/api/addresses/search/") { res in
                #expect(res.status == .notFound)
            }.test(.GET, "/api/addresses/search") { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("Test Throwing Group")
    func testThrowingGroup() async throws {
        _ = try await withApp { app in
            #expect(throws: Abort(.internalServerError, reason: "Test")) {
                try app.routes.group("foo") { router in
                    throw Abort(.internalServerError, reason: "Test")
                }
            }
        }
    }

    @Test("Test Collection")
    func testCollection() async throws {
        struct Foo: RouteCollection {
            func boot(routes: RoutesBuilder) throws {
                routes.get("foo") { _ in "bar" }
            }
        }

        try await withApp { app in
            try app.register(collection: Foo())

            try await app.test(.GET, "foo") { res in
                #expect(res.body.string == "bar")
            }
        }
    }

    @Test("Test Configurable Max Body Size")
    func testConfigurableMaxBodySize() async throws {
        try await withApp { app in
            #expect(app.routes.defaultMaxBodySize == 16384)
            app.routes.defaultMaxBodySize = 1
            #expect(app.routes.defaultMaxBodySize == 1)

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
            try await app.testing(method: .running(port: 0)).test(.POST, "/default", body: buffer) { res in
                #expect(res.status == .payloadTooLarge)
            }.test(.POST, "/1kb", body: buffer) { res in
                #expect(res.status == .payloadTooLarge)
            }.test(.POST, "/1mb", body: buffer) { res in
                #expect(res.status == .ok)
            }.test(.POST, "/1gb", body: buffer) { res in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Test Websocket Upgrade")
    func testWebsocketUpgrade() async throws {
        try await withApp { app in
            let testMarkerHeaderKey = "TestMarker"
            let testMarkerHeaderValue = "addedInShouldUpgrade"

            app.routes.webSocket("customshouldupgrade", shouldUpgrade: { req in
                [testMarkerHeaderKey: testMarkerHeaderValue]
            }, onUpgrade: { _, _ in })

            try await app.testing(method: .running(port: 0)).test(.GET, "customshouldupgrade", beforeRequest: { req async in
                req.headers.replaceOrAdd(name: HTTPHeaders.Name.secWebSocketVersion, value: "13")
                req.headers.replaceOrAdd(name: HTTPHeaders.Name.secWebSocketKey, value: "zyFJtLIpI2ASsmMHJ4Cf0A==")
                req.headers.replaceOrAdd(name: .connection, value: "Upgrade")
                req.headers.replaceOrAdd(name: .upgrade, value: "websocket")
            }) { res in
                #expect(res.headers.first(name: testMarkerHeaderKey) == testMarkerHeaderValue)
            }
        }
    }

    @Test("Test URL Client Request with Invalid URL Does Not Crash", .bug("https://github.com/vapor/vapor/issues/2716"))
    func testGH2716() async throws {
        try await withApp { app in
            app.get("client") { req in
                let response = try await req.client.get("http://localhost/status/2 1")
                return response.description
            }

            try await app.testing(method: .running(port: 0)).test(.GET, "/client") { res in
                #expect(res.status.code == 500)
            }
        }
    }

    @Test("Test Double Slash Route Access", .bug("https://github.com/vapor/vapor/issues/3137"), .bug("https://github.com/vapor/vapor/issues/3142"))
    func testDoubleSlashRouteAccess() async throws {
        try await withApp { app in
            app.get(":foo", ":bar", "buz") { req -> String in
                "\(try req.parameters.require("foo"))\(try req.parameters.require("bar"))"
            }

            try await app.testing(method: .running(port: 0)).test(.GET, "/foop/barp/buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "//foop/barp/buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "//foop//barp/buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "//foop//barp//buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "/foop//barp/buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "/foop//barp//buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "/foop/barp//buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }.test(.GET, "//foop/barp//buz") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "foopbarp")
            }
        }
    }
}

extension WebSocket: Swift.Hashable {
    public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
