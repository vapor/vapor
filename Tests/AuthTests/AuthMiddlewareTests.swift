import XCTest
import HTTP
@testable import Auth

class AuthMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testCustomCookieName", testCustomCookieName),
        ("testAuthHelperPersistence", testAuthHelperPersistence),
    ]

    func testCustomCookieName() throws {
        let cookieName = "custom-auth-cookie-name"
        let authMiddleware = AuthMiddleware(user: AuthUser.self, cookieName: cookieName)
        
        let request = try Request(method: .get, uri: "test")
        
        let responder = AuthMiddlewareResponser()
        let response = try authMiddleware.respond(to: request, chainingTo: responder)
        
        let cookie = response.cookies.cookies.first!
        XCTAssertEqual(cookie.name, cookieName)
        XCTAssertNotNil(cookie.value)
        XCTAssertNotNil(cookie.expires)
        XCTAssertFalse(cookie.secure)
        XCTAssertFalse(cookie.httpOnly)
    }

    func testAuthHelperPersistence() throws {
        let request = try Request(method: .get, uri: "test")
        let one = request.auth
        let two = request.auth
        let three = request.auth

        XCTAssert(one === two)
        XCTAssert(one === three)
        XCTAssert(two === three)
    }
}
