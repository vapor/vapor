import Vapor
import XCTest

class ErrorMiddlewareTests: XCTestCase {

    func testNotFoundError() throws {
        let app = try Application()
        let errorMiddleware = ErrorMiddleware.default(environment: app.environment, log: try app.make())
        
        let result = try errorMiddleware.respond(to: Request(using: app), chainingTo: NotFoundThrowingResponder()).wait()
        
        XCTAssertEqual(result.http.status, .notFound)
    }
}

private class NotFoundThrowingResponder: Responder {
    func respond(to req: Request) throws -> EventLoopFuture<Response> {
        throw NotFound(rootCause: nil)
    }
    
    
}
