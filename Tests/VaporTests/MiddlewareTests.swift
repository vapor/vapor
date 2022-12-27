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
    
    func testFileMiddlewareFromBundle() throws {
        var fileMiddleware: FileMiddleware!
        
        XCTAssertNoThrow(fileMiddleware = try FileMiddleware(bundle: .module, publicDirectory: "/"), "FileMiddleware instantiation from Bundle should not fail")
        
        let app = Application(.testing)
        defer { app.shutdown() }
        app.middleware.use(fileMiddleware)
        
        try app.testable().test(.GET, "/foo.txt") { result in
            XCTAssertEqual(result.status, .ok)
            XCTAssertEqual(result.body.string, "bar\n")
        }
    }
    
    func testFileMiddlewareFromBundleInvalidPublicDirectory() {
        XCTAssertThrowsError(try FileMiddleware(bundle: .module, publicDirectory: "/totally-real/folder")) { error in
            guard let error = error as? FileMiddleware.BundleSetupError else {
                return XCTFail("Error should be of type FileMiddleware.SetupError")
            }
            XCTAssertEqual(error, .publicDirectoryIsNotAFolder)
        }
    }
}
