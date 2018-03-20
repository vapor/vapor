import Vapor
import XCTest

class MiddlewareTests : XCTestCase {
    // https://github.com/vapor/vapor/issues/1371
    func testNotConfigurable() throws {
        final class MyMiddleware: Middleware {
            var flag = false
            func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
                flag = true
                return try next.respond(to: request)
            }
        }

        let myMiddleware = MyMiddleware()
        var services = Services.default()
        var middlewareConfig = MiddlewareConfig()
        middlewareConfig.use(myMiddleware)
        services.register(middlewareConfig)

        let app = try Application(services: services)

        let req = Request(using: app)
        _ = try app.make(Responder.self).respond(to: req).wait()
        XCTAssert(myMiddleware.flag == true)
    }

    static let allTests = [
        ("testNotConfigurable", testNotConfigurable),
    ]
}
