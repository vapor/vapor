import HTTPTypes
import Vapor
import Metrics
@testable import CoreMetrics
import MetricsTestKit
import NIOCore
import Tracing
import Testing
import VaporTesting
import RegexBuilder
import RoutingKit
import NIOConcurrencyHelpers
import InMemoryTracing
import Foundation

@Suite("Middleware Tests")
struct MiddlewareTests {
    @Test("Test Middleware Order")
    func testMiddlewareOrder() async throws {
        try await withApp { app in
            let store = OrderStore()
            app.grouped(
                OrderMiddleware("a", store: store), OrderMiddleware("b", store: store), OrderMiddleware("c", store: store)
            ).get("order") { req -> String in
                return "done"
            }

            try await app.testing { client in
                let res = try await client.get("/order")
                let order = await store.getOrder()
                #expect(res.status == .ok)
                #expect(order == ["a", "b", "c"])
                try #expect(await res.body.requireString() == "done")
            }
        }
    }

    @Test("Test Prepending Middleware")
    func testPrependingMiddleware() async throws {
        try await withApp { app in
            let store = OrderStore()
            app.middleware.use(OrderMiddleware("b", store: store))
            app.middleware.use(OrderMiddleware("c", store: store))
            app.middleware.use(OrderMiddleware("a", store: store), at: .beginning)
            app.middleware.use(OrderMiddleware("d", store: store), at: .end)

            app.get("order") { req -> String in
                return "done"
            }

            try await app.testing { client in
                let res = try await client.get("/order")
                let order = await store.getOrder()
                #expect(res.status == .ok)
                #expect(order == ["a", "b", "c", "d"])
                try #expect(await res.body.requireString() == "done")
            }
        }
    }

    @Test("Test CORS Middleware Any Allowed Origin")
    func testCORSMiddlewareAnyAllowedOrigin() async throws {
        try await withApp { app in
            app.grouped(
                CORSMiddleware(configuration: .init(allowedOrigin: .any(["foo", "bar"]), allowedMethods: [.get], allowedHeaders: [.origin]))
            ).get("order") { req -> String in
                return "done"
            }

            try await app.testing { client in
                let res = try await client.get("/order", headers: [.origin: "foo"])
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "done")
                #expect(res.headers[values: .vary] == ["origin"])
                #expect(res.headers[values: .accessControlAllowOrigin] == ["foo"])
                #expect(res.headers[values: .accessControlAllowHeaders] == ["origin"])
            }
        }
    }

    @Test("Test CORS Middleware Preflight Returns No Body")
    func testCORSMiddlewarePreflightReturnsNoBody() async throws {
        try await withApp { app in
            // Registered globally rather than on a route group: a preflight is an OPTIONS request
            // that matches no route, so middleware attached to the group never runs for it.
            app.middleware.use(
                CORSMiddleware(configuration: .init(allowedOrigin: .any(["foo"]), allowedMethods: [.get], allowedHeaders: [.origin]))
            )
            app.get("order") { req -> String in
                return "done"
            }

            // A preflight is answered by the middleware itself rather than the route, so it carries
            // the CORS headers and no body — the route's "done" must not leak into the response.
            let headers: HTTPFields = [.origin: "foo", .accessControlRequestMethod: "GET"]
            try await app.testing { client in
                let res = try await client.send(.options, headers: headers, to: "/order")
                #expect(res.status == .ok)
                #expect(res.body.count == 0)
                #expect(res.headers[values: .accessControlAllowOrigin] == ["foo"])
                #expect(res.headers[values: .accessControlAllowMethods] == ["GET"])
            }
        }
    }

    @Test("Test CORS Middleware Varied By Request Origin")
    func testCORSMiddlewareVariedByRequestOrigin() async throws {
        try await withApp { app in
            app.grouped(
                CORSMiddleware(configuration: .init(allowedOrigin: .originBased, allowedMethods: [.get], allowedHeaders: [.origin]))
            ).get("order") { req -> String in
                return "done"
            }

            try await app.testing { client in
                let res = try await client.get("/order", headers: [.origin: "foo"])
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "done")
                #expect(res.headers[values: .vary] == ["origin"])
                #expect(res.headers[values: .accessControlAllowOrigin] == ["foo"])
                #expect(res.headers[values: .accessControlAllowHeaders] == ["origin"])
            }
        }
    }

    @Test("Test CORS Middleware No Variation By Request Origin Allowed")
    func testCORSMiddlewareNoVariationByRequestOriginAllowed() async throws {
        try await withApp { app in
            app.grouped(
                CORSMiddleware(configuration: .init(allowedOrigin: .none, allowedMethods: [.get], allowedHeaders: []))
            ).get("order") { req -> String in
                return "done"
            }

            try await app.testing { client in
                let res = try await client.get("/order", headers: [.origin: "foo"])
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "done")
                #expect(res.headers[values: .vary] == [])
                #expect(res.headers[values: .accessControlAllowOrigin] == [])
                #expect(res.headers[values: .accessControlAllowHeaders] == [""])
            }
        }
    }

    @Test("Test CORS Middleware Dynamic Origin Allowed")
    func testCORSMiddlewareDynamicOriginAllowed() async throws {
        try await withApp { app in
            app.grouped(
                CORSMiddleware(configuration: .init(
                    allowedOrigin: .dynamic({ req in
                        guard let origin = req.headers[values: .origin].first else {
                            return ""
                        }
                        let regex = Regex {
                            Anchor.startOfLine
                            "http://example-"
                            OneOrMore {
                                CharacterClass.digit
                            }
                            ".com"
                            Anchor.endOfLine
                        }
                        let isMatch = origin.wholeMatch(of: regex) != nil
                        return isMatch ? origin : ""
                    }),
                    allowedMethods: [.get],
                    allowedHeaders: []
                ))
            ).get("order") { req -> String in
                return "done"
            }

            try await app.testing { client in
                let allowed = try await client.get("/order", headers: [.origin: "http://example-123.com"])
                #expect(allowed.status == .ok)
                try #expect(await allowed.body.requireString() == "done")
                #expect(allowed.headers[values: .vary] == ["origin"])
                #expect(allowed.headers[values: .accessControlAllowOrigin] == ["http://example-123.com"])
                #expect(allowed.headers[values: .accessControlAllowHeaders] == [""])

                let disallowed = try await client.get("/order", headers: [.origin: "foo"])
                #expect(disallowed.status == .ok)
                try #expect(await disallowed.body.requireString() == "done")
                #expect(disallowed.headers[values: .vary] == [])
                #expect(disallowed.headers[values: .accessControlAllowOrigin] == [])
                #expect(disallowed.headers[values: .accessControlAllowHeaders] == [""])
            }
        }
    }

    #if !canImport(FoundationEssentials)
    @Test("Test File Middleware From Bundle")
    func testFileMiddlewareFromBundle() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/", etagCache: app.fileETagHashCache)
            app.middleware.use(fileMiddleware)

            try await app.testing { client in
                let result = try await client.get("/foo.txt")
                #expect(result.status == .ok)
                try #expect(await result.body.requireString() == "bar\n")
                #expect(result.headers[.cacheControl] == nil)
                #expect(result.headers[.age] == nil)
            }
        }
    }

    @Test("Test File MIddleware With Browser Default Cache Policy")
    func testFileMiddlewareWithBrowserDefaultCachePolicy() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/", cachePolicy: .browserDefault, etagCache: app.fileETagHashCache)
            app.middleware.use(fileMiddleware)

            try await app.testing { client in
                let result = try await client.get("/foo.txt")
                #expect(result.status == .ok)
                try #expect(await result.body.requireString() == "bar\n")
                #expect(result.headers[.cacheControl] == nil)
                #expect(result.headers[.age] == nil)
            }

        }
    }

    @Test("Test File Middleware With No Cache Policy")
    func testFileMiddlewareWithNoCachePolicy() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/", cachePolicy: .noCache, etagCache: app.fileETagHashCache)
            app.middleware.use(fileMiddleware)

            try await app.testing { client in
                let result = try await client.get("/foo.txt")
                #expect(result.status == .ok)
                try #expect(await result.body.requireString() == "bar\n")
                #expect(result.headers[.cacheControl] == "no-cache")
                #expect(result.headers[.age] == nil)
            }
        }
    }

    @Test("Test File Middleware With Max Age Cache Policy")
    func testFileMiddlewareWithMaxAgeCachePolicy() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/", cachePolicy: .cache(upTo:
                    .seconds(300)), etagCache: app.fileETagHashCache)
            app.middleware.use(fileMiddleware)

            try await app.testing { client in
                let result = try await client.get("/foo.txt")
                #expect(result.status == .ok)
                try #expect(await result.body.requireString() == "bar\n")
                #expect(result.headers[.cacheControl] == "max-age=300")
                #expect(result.headers[.age] == "0")
            }
        }
    }

    @Test("Test File Middleware With Custom Cache Policy")
    func testFileMiddlewareWithCustomCachePolicy() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/", cachePolicy: .custom(cacheControlHeader: .init(isPublic: true), ageHeader: 10), etagCache: app.fileETagHashCache)
            app.middleware.use(fileMiddleware)

            try await app.testing { client in
                let result = try await client.get("/foo.txt")
                #expect(result.status == .ok)
                try #expect(await result.body.requireString() == "bar\n")
                #expect(result.headers[.cacheControl] == "public")
                #expect(result.headers[.age] == "10")
            }
        }
    }

    @Test("Test File Middleware From Bundle Subfolder")
    func testFileMiddlewareFromBundleSubfolder() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "SubUtilities", etagCache: app.fileETagHashCache)
            app.middleware.use(fileMiddleware)

            try await app.testing { client in
                let result = try await client.get("/index.html")
                #expect(result.status == .ok)
                try #expect(await result.body.requireString() == "<h1>Subdirectory Default</h1>\n")
            }
        }
    }

    @Test("Test File Middleware From Bundle Invalid Public Directory")
    func testFileMiddlewareFromBundleInvalidPublicDirectory() {
        #expect(throws: FileMiddleware.BundleSetupError.publicDirectoryIsNotAFolder) {
            try FileMiddleware(bundle: .module, publicDirectory: "/totally-real/folder", etagCache: FileETagHashCache(capacity: 10))
        }
    }
    #endif
    
    @Test("Test Metrics Middleware", .withMetrics(TestMetrics()))
    func testMetricsMiddleware() async throws {
        try await withApp { app in
            app.middleware.use(MetricsMiddleware())
            app.get("testMetrics") { req -> String in
                return "done"
            }
            let (response, notFoundResponse) = try await app.testing { client in
                let response = try await client.get("http://127.0.0.1/testMetrics")
                let notFoundResponse = try await client.get("http://127.0.0.1/not/found")
                return (response, notFoundResponse)
            }

            #expect(response.status == .ok)
            #expect(response.body.string == "done")

            let httpServerActiveRequests = try metrics.expectMeter(
                "http.server.active_requests",
                [
                    ("http.request.method", "GET"),
                    ("url.scheme", "http"),
                ]
            )
            #expect(httpServerActiveRequests.lastValue == 0.0)

            let httpServerRequestBodySize =  try metrics.expectRecorder(
                "http.server.request.body.size",
                [
                    ("http.request.method", "GET"),
                    ("url.scheme", "http"),
                    ("error.type", "undefined"),
                    ("http.response.status_code", "200"),
                    ("http.route", "/testMetrics"),
                    ("network.protocol.name", "http"),
                    ("network.protocol.version", "1.1"),
                ]
            )
            #expect(httpServerRequestBodySize.lastValue == 0.0)

            #expect(throws: Never.self) {
                try metrics.expectTimer(
                    "http.server.request.duration",
                    [
                        ("http.request.method", "GET"),
                        ("url.scheme", "http"),
                        ("error.type", "undefined"),
                        ("http.response.status_code", "200"),
                        ("http.route", "/testMetrics"),
                        ("network.protocol.name", "http"),
                        ("network.protocol.version", "1.1"),
                    ]
                )
            }

            let httpServerResponseBodySize =  try metrics.expectRecorder(
                "http.server.response.body.size",
                [
                    ("http.request.method", "GET"),
                    ("url.scheme", "http"),
                    ("error.type", "undefined"),
                    ("http.response.status_code", "200"),
                    ("http.route", "/testMetrics"),
                    ("network.protocol.name", "http"),
                    ("network.protocol.version", "1.1"),
                ]
            )
            #expect(httpServerResponseBodySize.lastValue == 4.0)

            // Test 404 Rewrites Path for Metrics to Avoid DOS Attack
            #expect(notFoundResponse.status == .notFound)
            let httpServerRequestDuration = try metrics.expectTimer(
                "http.server.request.duration",
                [
                    ("http.request.method", "GET"),
                    ("url.scheme", "http"),
                    ("error.type", "RouteNotFound"),
                    ("http.response.status_code", "404"),
                    ("http.route", "vapor_route_undefined"),
                    ("network.protocol.name", "http"),
                    ("network.protocol.version", "1.1"),
                ]
            )
            #expect(httpServerRequestDuration.values.count == 1)
        }
    }

    @Test("Metrics middleware records a streaming response body's declared size", .withMetrics(TestMetrics()))
    func testMetricsMiddlewareStreamingResponseBodySizeDeclared() async throws {
        try await withApp { app in
            app.middleware.use(MetricsMiddleware())
            // A stream that declares its length can be measured without reading it.
            app.get("streamMetrics") { _ in
                Response(body: try .init(stream: { writer in
                    try await writer.write("alpha")
                    try await writer.write("beta")
                }, count: 9))
            }

            let status = try await app.testing { client in
                try await client.get("http://127.0.0.1/streamMetrics").status
            }
            #expect(status == .ok)

            let recorder = try metrics.expectRecorder(
                "http.server.response.body.size",
                [
                    ("http.request.method", "GET"),
                    ("url.scheme", "http"),
                    ("error.type", "undefined"),
                    ("http.response.status_code", "200"),
                    ("http.route", "/streamMetrics"),
                    ("network.protocol.name", "http"),
                    ("network.protocol.version", "1.1"),
                ]
            )
            #expect(recorder.lastValue == 9.0)
        }
    }

    @Test("Metrics middleware records no body size for a stream of unknown length", .withMetrics(TestMetrics()))
    func testMetricsMiddlewareStreamingResponseBodySizeUnknown() async throws {
        try await withApp { app in
            app.middleware.use(MetricsMiddleware())
            // No declared length, and the middleware must not read the body to find one - so there is
            // no size to record. This used to record the `-1` sentinel as if it were a byte count.
            app.get("streamMetrics") { _ in
                Response(body: .init(stream: { writer in
                    try await writer.write("alpha")
                    try await writer.write("beta")
                }))
            }

            let (status, body) = try await app.testing { client in
                let response = try await client.get("http://127.0.0.1/streamMetrics")
                return (response.status, try await response.body.requireString())
            }
            #expect(status == .ok)
            #expect(body == "alphabeta")

            // The request itself is still measured; only the body size is absent.
            #expect(throws: Never.self) {
                try metrics.expectTimer(
                    "http.server.request.duration",
                    [
                        ("http.request.method", "GET"),
                        ("url.scheme", "http"),
                        ("error.type", "undefined"),
                        ("http.response.status_code", "200"),
                        ("http.route", "/streamMetrics"),
                        ("network.protocol.name", "http"),
                        ("network.protocol.version", "1.1"),
                    ]
                )
            }

            #expect(throws: (any Error).self) {
                try metrics.expectRecorder(
                    "http.server.response.body.size",
                    [
                        ("http.request.method", "GET"),
                        ("url.scheme", "http"),
                        ("error.type", "undefined"),
                        ("http.response.status_code", "200"),
                        ("http.route", "/streamMetrics"),
                        ("network.protocol.name", "http"),
                        ("network.protocol.version", "1.1"),
                    ]
                )
            }
        }
    }

    @Test("Test Tracing Middleware", .withTracer(InMemoryTracer()))
    func testTracingMiddleware() async throws {
        try await withApp { app in
            struct TestServiceContextMiddleware: Middleware {
                func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                    #expect(ServiceContext.current != nil)
                    return try await next.respond(to: request)
                }
            }

            app.grouped(
                TracingMiddleware(serverAddress: { app.sharedAddress.withLockedValue({ $0 }) }) { attributes, _ in
                    attributes["custom"] = "custom"
                }
            ).grouped(
                TestServiceContextMiddleware()
            ).get("testTracing") { req -> String in
                // Validates that the span's service context is propagated into the
                // Task.local storage of the responder closure, thereby ensuring that
                // spans created in the closure are nested under the request span.
                // Requires Application.traceAutoPropagation to be enabled
                #expect(ServiceContext.current != nil)
                return "done"
            }

            try await app.testing(method: .running()).test(.get, "/testTracing?foo=bar", beforeRequest: {
                $0.headers[.userAgent] = "test"
            }) { response in
                #expect(response.status == .ok)
                try #expect(await response.body.requireString() == "done")

                let span = try #require(tracer.finishedSpans.first)
                #expect(span.operationName == "GET /testTracing")

                #expect(span.attributes["http.request.method"]?.toSpanAttribute() == "GET")
                #expect(span.attributes["url.path"]?.toSpanAttribute() == "/testTracing")
                #expect(span.attributes["url.scheme"]?.toSpanAttribute() == nil)

                #expect(span.attributes["http.route"]?.toSpanAttribute() == "/testTracing")
                #expect(span.attributes["network.protocol.name"]?.toSpanAttribute() == "http")
                let serverAddress = span.attributes["server.address"]?.toSpanAttribute()
                #expect(serverAddress == "127.0.0.1" || serverAddress == "::1")
                let port = try #require(app.sharedAddress.withLockedValue({ $0 })?.port, "Failed to get port")
                #expect(span.attributes["server.port"]?.toSpanAttribute() == port.toSpanAttribute())
                #expect(span.attributes["url.query"]?.toSpanAttribute() == "foo=bar")

                let clientAddress = span.attributes["client.address"]?.toSpanAttribute()
                let networkPeerAddress = span.attributes["network.peer.address"]?.toSpanAttribute()
                #expect(clientAddress == "127.0.0.1" || clientAddress == "::1")
                #expect(networkPeerAddress == "127.0.0.1" || clientAddress == "::1")
                #expect(span.attributes["network.peer.port"]?.toSpanAttribute() != nil)
                #expect(span.attributes["network.protocol.version"]?.toSpanAttribute() == "1.1")
                #expect(span.attributes["user_agent.original"]?.toSpanAttribute() == "test")

                #expect(span.attributes["custom"]?.toSpanAttribute() == "custom")

                #expect(span.attributes["http.response.status_code"]?.toSpanAttribute() == 200)
            }
        }
    }
}

actor OrderStore {
    var order: [String] = []

    func addOrder(_ orderValue: String) {
        self.order.append(orderValue)
    }

    func getOrder() -> [String] {
        self.order
    }
}

final class OrderMiddleware: Middleware {
    let pos: String
    let store: OrderStore
    init(_ pos: String, store: OrderStore) {
        self.pos = pos
        self.store = store
    }
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        await store.addOrder(pos)
        return try await next.respond(to: request)
    }
}
