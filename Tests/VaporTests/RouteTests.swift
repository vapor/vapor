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
            try await app.testing().test(.get, "/hello/vapor") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString().contains("vapor"))
            }

            try await app.testing().test(.post, "/hello/vapor") { res in
                #expect(res.status == .notFound)
            }

            try await app.testing().test(.get, "/hello/vapor/development") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == #"["vapor","development"]"#)
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

            try await app.testing().test(.get, "/string/test") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString().contains("test"))
            }

            try await app.testing().test(.get, "/int/123") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "123")
            }

            try await app.testing().test(.get, "/int/not-int") { res in
                #expect(res.status == .unprocessableContent)
            }

            try await app.testing().test(.get, "/missing") { res in
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

            try await app.testing().test(.get, "/json") { res in
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

            try await app.testing().test(.get, "/") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "root")
            }

            try await app.testing().test(.get, "/foo") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "foo")
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

            try await app.testing().test(.get, "/foo") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "foo")
            }

            try await app.testing().test(.get, "/FOO") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "foo")
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

            try await app.testing().test(.get, "/foo", beforeRequest: { req in
                try req.query.encode(["number": "true"])
            }) { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "42")
            }

            try await app.testing().test(.get, "/foo", beforeRequest: { req in
                try req.query.encode(["number": "false"])
            }) { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "string")
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

            try await app.testing().test(.get, "/foo?number=true") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "42")
            }

            try await app.testing().test(.get, "/foo?number=false") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "string")
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

            try await app.testing().test(.post, "/users", beforeRequest: { req in
                try req.content.encode([
                    "name": "vapor",
                    "email": "foo"
                ], as: .json)
            }) { res in
                #expect(res.status == .badRequest)
                try #expect(await res.body.requireString().contains("email is not a valid email address"))
            }

            try await app.testing().test(.post, "/users") { res in
                #expect(res.status == .unprocessableContent)
                try #expect(await res.body.requireString().replacing("\\", with: "").contains("Missing \"Content-Type\" header"))
            }

            try await app.testing().test(.post, "/users", headers: [.contentType: "application/json"]) { res in
                #expect(res.status == .unprocessableContent)
                try #expect(await res.body.requireString().contains("Empty Body"))
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

            try await app.testing().test(.post, "/users", beforeRequest: { req async throws in
                try req.content.encode(["name": "vapor"], as: .json)
            }) { res in
                #expect(res.status == .created)
                #expect(res.headers.contentType == .json)
                try #expect(await res.body.requireString() == """
            {"name":"vapor"}
            """)
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

            try await app.testing(method: .running()).test(.head, "/hello") { res in
                #expect(res.status == .ok)
                #expect(res.headers[.contentLength] == "2")
                // The body has to be collected before it can be counted: an uncollected stream
                // reports `-1`, not the number of bytes that actually arrived.
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

            try await app.testing(method: .running()).test(.head, "/hello") { res in
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
            try await app.testing().test(.get, "/get", headers: headers) { res in
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

            try await app.testing(method: .running()).test(.get, "/no-content") { res in
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

            try await app.test(method: .running()) { testApp in
                let rootResponse = try await testApp.sendRequest(.get, "/api/addresses")
                try #expect(await rootResponse.body.requireString() == "a")

                let testResponse = try await testApp.sendRequest(.get, "/api/addresses/search/test")
                try #expect(await testResponse.body.requireString() == "b")

                let emptySearch = try await testApp.sendRequest(.get, "/api/addresses/search")
                #expect(emptySearch.status == .notFound)

                let emptySearchRoot = try await testApp.sendRequest(.get, "/api/addresses/search/")
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

            try await app.test(.get, "foo") { res in
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
            try await app.testing(method: .running()).test(.post, "/default", body: buffer) { res in
                #expect(res.status == .contentTooLarge)
            }

            try await app.testing(method: .running()).test(.post, "/1kb", body: buffer) { res in
                #expect(res.status == .contentTooLarge)
            }

            try await app.testing(method: .running()).test(.post, "/1mb", body: buffer) { res in
                #expect(res.status == .ok)
            }

            try await app.testing(method: .running()).test(.post, "/1gb", body: buffer) { res in
                #expect(res.status == .ok)
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

            try await app.test(method: .running()) { testApp in
                let happyPath = try await testApp.sendRequest(.get, "/foop/barp/buz")
                try #expect(await happyPath.body.requireString() == "foopbarp")
                #expect(happyPath.status == .ok)

                let leadingDoubleSlash = try await testApp.sendRequest(.get, "//foop/barp/buz")
                try #expect(await leadingDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingDoubleSlash.status == .ok)

                let leadingAndMiddleDoubleSlash = try await testApp.sendRequest(.get, "//foop//barp/buz")
                try #expect(await leadingAndMiddleDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingAndMiddleDoubleSlash.status == .ok)

                let leadingMiddleAndTrailingDoubleSlash = try await testApp.sendRequest(.get, "//foop//barp//buz")
                try #expect(await leadingMiddleAndTrailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(leadingMiddleAndTrailingDoubleSlash.status == .ok)

                let middleDoubleSlash = try await testApp.sendRequest(.get, "/foop//barp/buz")
                try #expect(await middleDoubleSlash.body.requireString() == "foopbarp")
                #expect(middleDoubleSlash.status == .ok)

                let middleAndTrailingDoubleSlash = try await testApp.sendRequest(.get, "/foop//barp//buz")
                try #expect(await middleAndTrailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(middleAndTrailingDoubleSlash.status == .ok)

                let trailingDoubleSlash = try await testApp.sendRequest(.get, "/foop/barp//buz")
                try #expect(await trailingDoubleSlash.body.requireString() == "foopbarp")
                #expect(trailingDoubleSlash.status == .ok)

                let leadingAndTrailingDoubleSlash = try await testApp.sendRequest(.get, "//foop/barp//buz")
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
            for method in methods {
                try await app.testing().test(method, "/universal") { res in
                    #expect(res.status == .ok)
                    try #expect(await res.body.requireString() == method.rawValue)
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

            try await app.test(method: .running()) { testApp in
                let emoticon = try await testApp.sendRequest(.get, "/Good👍")
                try #expect(await emoticon.body.requireString() == "👍")
                #expect(emoticon.status == .ok)

                let japanese = try await testApp.sendRequest(.get, "/ようこそ世界へ")
                try #expect(await japanese.body.requireString() == "おめでとう")
                #expect(japanese.status == .ok)
            }
        }
    }
}
