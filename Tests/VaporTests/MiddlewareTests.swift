import HTTPTypes
import Vapor
import NIOCore
import Tracing
import Testing
import VaporTesting

@Suite("Middleware Tests")
struct MiddlewareTests2 {
    @Test("Test Middleware Order")
    func testMiddlewareOrder() async throws {
        try await withApp { app in
            let store = OrderStore()
            app.grouped(
                OrderMiddleware("a", store: store), OrderMiddleware("b", store: store), OrderMiddleware("c", store: store)
            ).get("order") { req -> String in
                return "done"
            }

            try await app.testing().test(.get, "/order") { res in
                let order = await store.getOrder()
                #expect(res.status == .ok)
                #expect(order == ["a", "b", "c"])
                #expect(res.body.string == "done")
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

            try await app.testing().test(.get, "/order") { res in
                let order = await store.getOrder()
                #expect(res.status == .ok)
                #expect(order == ["a", "b", "c", "d"])
                #expect(res.body.string == "done")
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

            try await app.testing().test(.get, "/order", headers: [.origin: "foo"]) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "done")
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

            try await app.testing().test(.get, "/order", headers: [.origin: "foo"]) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "done")
                #expect(res.headers[values: .vary] == [])
                #expect(res.headers[values: .accessControlAllowOrigin] == [])
                #expect(res.headers[values: .accessControlAllowHeaders] == [""])
            }
        }
    }

    @Test("Test File Middleware From Bundle")
    func testFileMiddlewareFromBundle() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/")
            app.middleware.use(fileMiddleware)

            try await app.testing().test(.get, "/foo.txt") { result async in
                #expect(result.status == .ok)
                #expect(result.body.string == "bar\n")
            }
        }
    }

    @Test("Test File Middleware From Bundle Subfolder")
    func testFileMiddlewareFromBundleSubfolder() async throws {
        try await withApp { app in
            let fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "SubUtilities")
            app.middleware.use(fileMiddleware)

            try await app.testing().test(.get, "/index.html") { result async in
                #expect(result.status == .ok)
                #expect(result.body.string == "<h1>Subdirectory Default</h1>\n")
            }
        }
    }

    @Test("Test File Middleware From Bundle Invalid Public Directory")
    func testFileMiddlewareFromBundleInvalidPublicDirectory() {
        #expect(throws: FileMiddleware.BundleSetupError.publicDirectoryIsNotAFolder) {
            try FileMiddleware(bundle: .module, publicDirectory: "/totally-real/folder")
        }
    }

    @Test("Test Tracing Middleware")
    func testTracingMiddleware() async throws {
        try await withApp { app in
            app.traceAutoPropagation = true
            let tracer = TestTracer()
            InstrumentationSystem.bootstrap(tracer)

            struct TestServiceContextMiddleware: Middleware {
                func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                    #expect(ServiceContext.current != nil)
                    return try await next.respond(to: request)
                }
            }

            app.grouped(
                TracingMiddleware() { attributes, _ in
                    attributes["custom"] = "custom"
                }
            ).grouped(
                TestServiceContextMiddleware()
            ).get("testTracing") { req -> String in
                // Validates that TracingMiddleware sets the serviceContext
                #expect(req.serviceContext != nil)
                // Validates that TracingMiddleware exposes header extraction to backend
                #expect(req.serviceContext.extracted == "extracted")
                // Validates that the span's service context is propagated into the
                // Task.local storage of the responder closure, thereby ensuring that
                // spans created in the closure are nested under the request span.
                // Requires Application.traceAutoPropagation to be enabled
                #expect(ServiceContext.current != nil)
                return "done"
            }

            try await app.testing(method: .running).test(.get, "/testTracing?foo=bar", beforeRequest: {
                $0.headers[.userAgent] = "test"
                $0.headers[TestTracer.extractKey] = "extracted"
            }) { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "done")

                let span = try #require(tracer.spans.first)
                #expect(span.operationName == "GET /testTracing")

                #expect(span.attributes["http.request.method"]?.toSpanAttribute() == "GET")
                #expect(span.attributes["url.path"]?.toSpanAttribute() == "/testTracing")
                #expect(span.attributes["url.scheme"]?.toSpanAttribute() == nil)

                #expect(span.attributes["http.route"]?.toSpanAttribute() == "/testTracing")
                #expect(span.attributes["network.protocol.name"]?.toSpanAttribute() == "http")
                #expect(span.attributes["server.address"]?.toSpanAttribute() == "127.0.0.1")
                let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port, "Failed to get port")
                #expect(span.attributes["server.port"]?.toSpanAttribute() == port.toSpanAttribute())
                #expect(span.attributes["url.query"]?.toSpanAttribute() == "foo=bar")

                #expect(span.attributes["client.address"]?.toSpanAttribute() == "127.0.0.1")
                #expect(span.attributes["network.peer.address"]?.toSpanAttribute() == "127.0.0.1")
                #expect(span.attributes["network.peer.port"]?.toSpanAttribute() != nil)
                #expect(span.attributes["network.protocol.version"]?.toSpanAttribute() == "1.1")
                #expect(span.attributes["user_agent.original"]?.toSpanAttribute() == "test")

                #expect(span.attributes["custom"]?.toSpanAttribute() == "custom")

                #expect(span.attributes["http.response.status_code"]?.toSpanAttribute() == 200)
            }

//            try await app.server.start(address: .hostname("127.0.0.1", port: 0))
//
//            let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port, "Failed to get port")
//            let response = try await app.client.get("http://localhost:\(port)/testTracing?foo=bar") { req in
//                req.headers[.userAgent] = "test"
//                req.headers[TestTracer.extractKey] = "extracted"
//            }
//
//            #expect(response.status == .ok)
//            #expect(response.body?.string == "done")
//
//            let span = try #require(tracer.spans.first)
//            #expect(span.operationName == "GET /testTracing")
//
//            #expect(span.attributes["http.request.method"]?.toSpanAttribute() == "GET")
//            #expect(span.attributes["url.path"]?.toSpanAttribute() == "/testTracing")
//            #expect(span.attributes["url.scheme"]?.toSpanAttribute() == nil)
//
//            #expect(span.attributes["http.route"]?.toSpanAttribute() == "/testTracing")
//            #expect(span.attributes["network.protocol.name"]?.toSpanAttribute() == "http")
//            #expect(span.attributes["server.address"]?.toSpanAttribute() == "127.0.0.1")
//            #expect(span.attributes["server.port"]?.toSpanAttribute() == port.toSpanAttribute())
//            #expect(span.attributes["url.query"]?.toSpanAttribute() == "foo=bar")
//
//            #expect(span.attributes["client.address"]?.toSpanAttribute() == "127.0.0.1")
//            #expect(span.attributes["network.peer.address"]?.toSpanAttribute() == "127.0.0.1")
//            #expect(span.attributes["network.peer.port"]?.toSpanAttribute() != nil)
//            #expect(span.attributes["network.protocol.version"]?.toSpanAttribute() == "1.1")
//            #expect(span.attributes["user_agent.original"]?.toSpanAttribute() == "test")
//
//            #expect(span.attributes["custom"]?.toSpanAttribute() == "custom")
//
//            #expect(span.attributes["http.response.status_code"]?.toSpanAttribute() == 200)
//
//            try await app.server.shutdown()
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
