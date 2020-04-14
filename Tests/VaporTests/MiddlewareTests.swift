@testable import Vapor
import XCTVapor

final class MiddlewareTests: XCTestCase {
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

    func testCorsPosition() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let cors = CORSMiddleware.init(configuration: .default())
        app.middleware.use(cors)

        let middlewares = app.middleware.resolve()

        let errorMiddleware = try XCTUnwrap(middlewares.firstIndex(where: { $0 is ErrorMiddleware }))
        let corsMiddleware = try XCTUnwrap(middlewares.firstIndex(where: { $0 is CORSMiddleware }))

        XCTAssertLessThan(corsMiddleware, errorMiddleware)
    }
}
