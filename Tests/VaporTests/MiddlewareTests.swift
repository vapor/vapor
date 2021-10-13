import XCTVapor

final class MiddlewareTests: XCTestCase {
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

    func testMiddlewareOrder() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        OrderMiddleware.order = []
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

    func testPrependingMiddleware() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        OrderMiddleware.order = []
        app.middleware.use(OrderMiddleware("b"));
        app.middleware.use(OrderMiddleware("c"));
        app.middleware.use(OrderMiddleware("a"), at: .beginning);
        app.middleware.use(OrderMiddleware("d"), at: .end);

        app.get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(OrderMiddleware.order, ["a", "b", "c", "d"])
            XCTAssertEqual(res.body.string, "done")
        }
    }

    func testCORSMiddlewareVariedByRequestOrigin() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.grouped(
            CORSMiddleware(configuration: .init(allowedOrigin: .originBased, allowedMethods: [.GET], allowedHeaders: [.origin]))
        ).get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order", headers: ["Origin": "foo"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "done")
            XCTAssertEqual(res.headers[.vary], ["origin"])
            XCTAssertEqual(res.headers[.accessControlAllowOrigin], ["foo"])
            XCTAssertEqual(res.headers[.accessControlAllowHeaders], ["origin"])
            print(res.headers)
        }
    }

    func testCORSMiddlewareNoVariationByRequstOriginAllowed() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.grouped(
            CORSMiddleware(configuration: .init(allowedOrigin: .none, allowedMethods: [.GET], allowedHeaders: []))
        ).get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order", headers: ["Origin": "foo"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "done")
            XCTAssertEqual(res.headers[.vary], [])
            XCTAssertEqual(res.headers[.accessControlAllowOrigin], [""])
            XCTAssertEqual(res.headers[.accessControlAllowHeaders], [""])
            print(res.headers)
        }
    }
}

#if compiler(>=5.5) && canImport(_Concurrency)
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
final class AsyncMiddlewareTests: XCTestCase {
    final class OrderMiddleware: AsyncMiddleware {
        static var order: [String] = []
        let pos: String
        init(_ pos: String) {
            self.pos = pos
        }
        func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
            OrderMiddleware.order.append(pos)
            return try await next.respond(to: request)
        }
    }

    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    func testMiddlewareOrder() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        OrderMiddleware.order = []
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

    func testPrependingMiddleware() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        OrderMiddleware.order = []
        app.middleware.use(OrderMiddleware("b"));
        app.middleware.use(OrderMiddleware("c"));
        app.middleware.use(OrderMiddleware("a"), at: .beginning);
        app.middleware.use(OrderMiddleware("d"), at: .end);

        app.get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(OrderMiddleware.order, ["a", "b", "c", "d"])
            XCTAssertEqual(res.body.string, "done")
        }
    }

    func testCORSMiddlewareVariedByRequestOrigin() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.grouped(
            CORSMiddleware(configuration: .init(allowedOrigin: .originBased, allowedMethods: [.GET], allowedHeaders: [.origin]))
        ).get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order", headers: ["Origin": "foo"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "done")
            XCTAssertEqual(res.headers[.vary], ["origin"])
            XCTAssertEqual(res.headers[.accessControlAllowOrigin], ["foo"])
            XCTAssertEqual(res.headers[.accessControlAllowHeaders], ["origin"])
            print(res.headers)
        }
    }

    func testCORSMiddlewareNoVariationByRequstOriginAllowed() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.grouped(
            CORSMiddleware(configuration: .init(allowedOrigin: .none, allowedMethods: [.GET], allowedHeaders: []))
        ).get("order") { req -> String in
            return "done"
        }

        try app.testable().test(.GET, "/order", headers: ["Origin": "foo"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "done")
            XCTAssertEqual(res.headers[.vary], [])
            XCTAssertEqual(res.headers[.accessControlAllowOrigin], [""])
            XCTAssertEqual(res.headers[.accessControlAllowHeaders], [""])
            print(res.headers)
        }
    }
}
#endif
