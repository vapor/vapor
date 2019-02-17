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
        do {
            _ = try app.make(Responder.self).respond(to: req).wait()
        } catch {}
        XCTAssert(myMiddleware.flag == true)
    }
    
    func testCustomErrorEncoding() throws {
        struct MyCustomError: Error, Content {
            var flag: Bool
        }
        
        var services = Services.default()
        var middlewareConfig = MiddlewareConfig()
        middlewareConfig.use(ErrorMiddleware.self)
        services.register(middlewareConfig)
        
        let router = EngineRouter.default()
        router.get { (req) -> String in
            throw MyCustomError(flag: true)
        }
        services.register(router, as: Router.self)
        
        let app = try Application(services: services)
        
        let req = Request(http: .init(method: .GET, url: "/", version: .init(major: 1, minor: 1)), using: app)
        let response = try app.make(Responder.self).respond(to: req).wait()
        
        let error = try response.content.decode(MyCustomError.self).wait()
        XCTAssert(error.flag)
    }

    static let allTests = [
        ("testNotConfigurable", testNotConfigurable),
        ("testCustomErrorEncoding", testCustomErrorEncoding)
    ]
}
