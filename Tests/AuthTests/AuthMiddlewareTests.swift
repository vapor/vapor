import XCTest
import HTTP
@testable import Auth

class AuthMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testCustomCookieName", testCustomCookieName),
    ]

    func testCustomCookieName() throws {
        let cookieName = "custom-auth-cookie-name"
        let authMiddleware = AuthMiddleware(user: AuthUser.self, cookieName: cookieName)
        
        let request = try Request(method: .get, uri: "test")
        
        let responder = AuthMiddlewareResponser()
        let response = try authMiddleware.respond(to: request, chainingTo: responder)
        
        let cookie = response.cookies[cookieName]
        XCTAssertNotNil(cookie)
    }
}
