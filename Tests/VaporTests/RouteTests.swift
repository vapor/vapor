import NIOCore
import Testing
import VaporTesting
import Vapor
import HTTPTypes
import RoutingKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
            try await app.testing { client in
                let single = try await client.get("/hello/vapor")
                #expect(single.status == .ok)
                try #expect(await single.body.requireString().contains("vapor"))

                let wrongMethod = try await client.post("/hello/vapor")
                #expect(wrongMethod.status == .notFound)

                let double = try await client.get("/hello/vapor/development")
                #expect(double.status == .ok)
                try #expect(await double.body.requireString() == #"["vapor","development"]"#)
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

            try await app.testing { client in
                let string = try await client.get("/string/test")
                #expect(string.status == .ok)
                try #expect(await string.body.requireString().contains("test"))

                let int = try await client.get("/int/123")
                #expect(int.status == .ok)
                try #expect(await int.body.requireString() == "123")

                let notAnInt = try await client.get("/int/not-int")
                #expect(notAnInt.status == .unprocessableContent)

                let missing = try await client.get("/missing")
                #expect(missing.status == .internalServerError)
            }
        }
    }

    @Test("Test JSON")
    func testJSON() async throws {
        try await withApp { app in
            app.routes.get("json") { req -> [String: String] in
                return ["foo": "bar"]
            }

            try await app.testing { client in
                let res = try await client.get("/json")
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == #"{"foo":"bar"}"#)
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

            try await app.testing { client in
                let root = try await client.get("/")
                #expect(root.status == .ok)
                try #expect(await root.body.requireString() == "root")

                let foo = try await client.get("/foo")
                #expect(foo.status == .ok)
                try #expect(await foo.body.requireString() == "foo")
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

            try await app.testing { client in
                let lowercase = try await client.get("/foo")
                #expect(lowercase.status == .ok)
                try #expect(await lowercase.body.requireString() == "foo")

                let uppercase = try await client.get("/FOO")
                #expect(uppercase.status == .ok)
                try #expect(await uppercase.body.requireString() == "foo")
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

            try await app.testing { client in
                let number = try await client.get("/foo") { req in
                    try req.query.encode(["number": "true"])
                }
                #expect(number.status == .ok)
                try #expect(await number.body.requireString() == "42")

                let string = try await client.get("/foo") { req in
                    try req.query.encode(["number": "false"])
                }
                #expect(string.status == .ok)
                try #expect(await string.body.requireString() == "string")
            }
        }
    }

    @Test("Test Enum Response")
    func testEnumResponse() async throws {
        enum IntOrString: ResponseEncodable {
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

            try await app.testing { client in
                let number = try await client.get("/foo?number=true")
                #expect(number.status == .ok)
                try #expect(await number.body.requireString() == "42")

                let string = try await client.get("/foo?number=false")
                #expect(string.status == .ok)
                try #expect(await string.body.requireString() == "string")
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
                return try await req.content.decode(User.self)
            }

            try await app.testing { client in
                let invalidEmail = try await client.post("/users") { req in
                    try req.content.encode([
                        "name": "vapor",
                        "email": "foo"
                    ], as: .json)
                }
                #expect(invalidEmail.status == .badRequest)
                try #expect(await invalidEmail.body.requireString().contains("email is not a valid email address"))

                let noContentType = try await client.post("/users")
                #expect(noContentType.status == .unprocessableContent)
                try #expect(await noContentType.body.requireString().replacing("\\", with: "").contains("Missing \"Content-Type\" header"))

                let emptyBody = try await client.post("/users", headers: [.contentType: "application/json"])
                #expect(emptyBody.status == .unprocessableContent)
                try #expect(await emptyBody.body.requireString().contains("Empty Body"))
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

            try await app.testing { client in
                let res = try await client.post("/users") { req in
                    try req.content.encode(["name": "vapor"], as: .json)
                }
                #expect(res.status == .created)
                #expect(res.headers.contentType == .json)
                try #expect(await res.body.requireString() == #"{"name":"vapor"}"#)
            }
        }
    }

    @Test("Test Head Request Forwarded to Get")
    func testHeadRequestForwardedToGet() async throws {
        try await withApp { app in
            app.get("hello") { req -> String in
                #expect(req.method == .head)
                return "hi"
            }

            try await app.testing(.running) { client in
                let res = try await client.send(.head, to: "/hello")
                #expect(res.status == .ok)
                #expect(res.headers[.contentLength] == "2")
                // The body has to be collected before it can be counted: an uncollected stream
                // has no length, only the declared one.
                try #expect(await res.body.data()?.count == 0)
            }
        }
    }

    @Test("Test Explicit Head Route Overrides Forwarding to Get")
    func testExplicitHeadRouteOverridesForwardingToGet() async throws {
        try await withApp { app in
            app.get("hello") { req -> Response in
                return Response(status: .badRequest)
            }

            app.on(.head, "hello") { req -> Response in
                return Response(status: .found)
            }

            try await app.testing(.running) { client in
                let res = try await client.send(.head, to: "/hello")
                #expect(res.status == .found)
                #expect(res.headers[.contentLength] == "0")
                try #expect(await res.body.data()?.count == 0)
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

            var headers = HTTPFields()
            var cookies = HTTPCookies()
            cookies["vapor-session"] = "asdf"
            headers.cookie = cookies
            try await app.testing { client in
                let res = try await client.get("/get", headers: headers)
                #expect(res.status == .ok)
                #expect(res.headers[.setCookie] != nil)
                try #expect(await res.body.requireString() == "n/a")
            }
        }
    }

    @Test("Test Throwing .noContent Does Not Close Connection", .bug("https://github.com/vapor/vapor/issues/1787"))
    func testGH1787() async throws {
        try await withApp { app in
            app.get("no-content") { req -> String in
                throw Abort(.noContent)
            }

            try await app.testing(.running) { client in
                let res = try await client.get("/no-content")
                #expect(res.status.code == 204)
                try #expect(await res.body.data()?.count == 0)
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

            try await app.testing(.running) { client in
                let rootResponse = try await client.get("/api/addresses")
                try #expect(await rootResponse.body.requireString() == "a")

                let testResponse = try await client.get("/api/addresses/search/test")
                try #expect(await testResponse.body.requireString() == "b")

                let emptySearch = try await client.get("/api/addresses/search")
                #expect(emptySearch.status == .notFound)

                let emptySearchRoot = try await client.get("/api/addresses/search/")
                #expect(emptySearchRoot.status == .notFound)
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
            func boot(routes: any RoutesBuilder) throws {
                routes.get("foo") { _ in "bar" }
            }
        }

        try await withApp { app in
            try await app.register(collection: Foo())

            try await app.testing { client in
                let res = try await client.get("/foo")
                try #expect(await res.body.requireString() == "bar")
            }
        }
    }

    @Test("Test Configurable Max Body Size", .disabled())
    func testConfigurableMaxBodySize() async throws {
        try await withApp { app in
            #expect(app.routes.defaultMaxBodySize == 16384)
            app.routes.defaultMaxBodySize = 1
            #expect(app.routes.defaultMaxBodySize == 1)

            app.on(.post, "default") { request in
                HTTPResponse.Status.ok
            }
            app.on(.post, "1kb", body: .collect(maxSize: "1kb")) { request in
                HTTPResponse.Status.ok
            }
            app.on(.post, "1mb", body: .collect(maxSize: "1mb")) { request in
                HTTPResponse.Status.ok
            }
            app.on(.post, "1gb", body: .collect(maxSize: "1gb")) { request in
                HTTPResponse.Status.ok
            }

            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            buffer.writeBytes(Array(repeating: 0, count: 500_000))
            try await app.testing(.running) { client in
                let defaultLimit = try await client.post("/default") { $0.body = buffer }
                #expect(defaultLimit.status == .contentTooLarge)

                let oneKB = try await client.post("/1kb") { $0.body = buffer }
                #expect(oneKB.status == .contentTooLarge)

                let oneMB = try await client.post("/1mb") { $0.body = buffer }
                #expect(oneMB.status == .ok)

                let oneGB = try await client.post("/1gb") { $0.body = buffer }
                #expect(oneGB.status == .ok)
            }
        }
    }

    #if WebSockets
    @Test("Test Websocket Upgrade", .disabled())
    func testWebsocketUpgrade() async throws {
//        try await withApp { app in
//            let testMarkerHeaderKey: HTTPField.Name = .init("TestMarker")!
//            let testMarkerHeaderValue = "addedInShouldUpgrade"
//
//            app.routes.webSocket("customshouldupgrade", shouldUpgrade: { req in
//                [testMarkerHeaderKey: testMarkerHeaderValue]
//            }, onUpgrade: { _, _ in })
//
//            try await app.testing(method: .running()).test(.get, "customshouldupgrade", beforeRequest: { req async in
//                req.headers[.secWebSocketVersion] = "13"
//                req.headers[.secWebSocketKey] = "zyFJtLIpI2ASsmMHJ4Cf0A=="
//                req.headers[.connection] = "Upgrade"
//                req.headers[.upgrade] = "websocket"
//            }) { res in
//                #expect(res.headers[testMarkerHeaderKey] == testMarkerHeaderValue)
//            }
//        }
    }
    #endif

    @Test("Test Double Slash Route Access", .bug("https://github.com/vapor/vapor/issues/3137"), .bug("https://github.com/vapor/vapor/issues/3142"))
    func testDoubleSlashRouteAccess() async throws {
        try await withApp { app in
            app.get(":foo", ":bar", "buz") { req -> String in
                "\(try req.parameters.require("foo"))\(try req.parameters.require("bar"))"
            }

            try await app.testing(.running) { client in
                // A literal like `"//foop/barp/buz"` parses as a URL with host `foop`, so the paths
                // under test are set as a path component against the server's own base URL.
                let base = try #require(client.baseURL)
                func url(_ path: String) -> URI {
                    URI(scheme: base.scheme, host: base.host, port: base.port, path: path)
                }

                let happyPath = try await client.get(url("/foop/barp/buz"))
                try #expect(await happyPath.body.requireString() == "foopbarp")
                #expect(happyPath.status == .ok)

                let leadingDoubleSlash = try await client.get(url("//foop/barp/buz"))
                try #expect(await leadingDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingDoubleSlash.status == .ok)

                let leadingAndMiddleDoubleSlash = try await client.get(url("//foop//barp/buz"))
                try #expect(await leadingAndMiddleDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingAndMiddleDoubleSlash.status == .ok)

                let leadingMiddleAndTrailingDoubleSlash = try await client.get(url("//foop//barp//buz"))
                try #expect(await leadingMiddleAndTrailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingMiddleAndTrailingDoubleSlash.status == .ok)

                let middleDoubleSlash = try await client.get(url("/foop//barp/buz"))
                try #expect(await middleDoubleSlash.body.requireString() == "foopbarp")
                #expect(middleDoubleSlash.status == .ok)

                let middleAndTrailingDoubleSlash = try await client.get(url("/foop//barp//buz"))
                try #expect(await middleAndTrailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(middleAndTrailingDoubleSlash.status == .ok)

                let trailingDoubleSlash = try await client.get(url("/foop/barp//buz"))
                try #expect(await trailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(trailingDoubleSlash.status == .ok)

                let leadingAndTrailingDoubleSlash = try await client.get(url("//foop/barp//buz"))
                try #expect(await leadingAndTrailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingAndTrailingDoubleSlash.status == .ok)
            }
        }
    }

    @Test("Catch all HTTP methods", .bug("https://github.com/vapor/vapor/issues/1887"))
    func testCatchAllHTTPMethods() async throws {
        try await withApp { app in
            app.routes.all("universal") { req -> String in
                req.method.rawValue
            }

            let methods: [HTTPRequest.Method] = [.get, .post, .put, .patch, .delete, .head, .options]
            try await app.testing { client in
                for method in methods {
                    let res = try await client.send(method, to: "/universal")
                    #expect(res.status == .ok, "\(method)")
                    try #expect(await res.body.requireString() == method.rawValue, "\(method)")
                }
            }
        }
    }

    @Test("Unicode Routing", .bug("https://github.com/vapor/vapor/issues/3309"))
    func unicodeRouting() async throws {
        try await withApp { app in
            app.get("Good👍") { req in
                return "👍"
            }
            app.get("ようこそ世界へ") { req in
                return "おめでとう"
            }

            try await app.testing(.running) { client in
                let emoticon = try await client.get("/Good👍")
                try #expect(await emoticon.body.requireString() == "👍")
                #expect(emoticon.status == .ok)

                let japanese = try await client.get("/ようこそ世界へ")
                try #expect(await japanese.body.requireString() == "おめでとう")
                #expect(japanese.status == .ok)
            }
        }
    }
}
