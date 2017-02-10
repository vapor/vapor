import XCTest
import HTTP
import Cookies
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
        XCTAssertTrue(cookie.httpOnly)
    }
    
    func testCustomCookie() throws {
        let expires = Date()
        let cookieName = "custom-auth-cookie-name"
        let authMiddleware = AuthMiddleware(user: AuthUser.self, cookieName: cookieName) { name, value in
            return Cookie(
                name: name,
                value: value,
                expires: expires,
                secure: true,
                httpOnly: true
            )
        }
        
        let request = try Request(method: .get, uri: "test")
        
        let responder = AuthMiddlewareResponser()
        let response = try authMiddleware.respond(to: request, chainingTo: responder)
        
        let cookie = response.cookies.cookies.first!
        XCTAssertEqual(cookie.name, cookieName)
        XCTAssertNotNil(cookie.value)
        XCTAssertEqual(cookie.expires, expires)
        XCTAssertTrue(cookie.secure)
        XCTAssertTrue(cookie.httpOnly)
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
