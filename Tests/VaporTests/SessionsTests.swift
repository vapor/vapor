import XCTest
import Session
import Vapor
import HTTP
import Core
import Cookies
import Service

class SessionsTests: XCTestCase {
    func testExample() throws {
        let s = MemorySessions()
        let m = SessionsMiddleware(sessions: s)

        var config = Config()
        try config.set("droplet", "middleware", to: ["m"])
        
        var services = Services.default()
        services.register(m, name: "m", supports: [Middleware.self])
        
        let drop = try Droplet(config, services)

        drop.get("set") { req in
            try req.assertSession().data["foo"] = .string("bar")
            try req.assertSession().data["bar"] = .string("baz")
            return "set"
        }

        drop.get("get") { req in
            return try req.assertSession().data["foo"]?.string ?? "fail"
        }

        let req = Request(method: .get, path: "set")
        let res = try drop.respond(to: req)

        guard let c = res.cookies["vapor-session"] else {
            XCTFail("No cookie")
            return
        }
        
        guard let cookieIndex = res.cookies.index(of: "vapor-session") else {
            XCTFail("No cookie")
            return
        }
        
        let cookie = res.cookies.cookies[cookieIndex]
        
        XCTAssertTrue(cookie.httpOnly)
        XCTAssertEqual(cookie.path, "/")

        let req2 = Request(method: .get, path: "get")
        req2.cookies["vapor-session"] = c
        let res2 = try drop.respond(to: req2)

        XCTAssertEqual(res2.body.bytes?.makeString(), "bar")
    }
    
    func testCustomCookieFactoryWithExpiryDate() throws {
        let s = MemorySessions()
        let cookieName = "test-name"

        var config = Config()
        try config.set("droplet", "middleware", to: ["m"])

        let m = SessionsMiddleware(sessions: s, cookieName: cookieName) { req, cookie in
            var cookie = cookie

            if req.storage["session_expiry"] as? Bool ?? false {
                let oneMonthTime: TimeInterval = 30 * 24 * 60 * 60
                cookie.expires = Date().addingTimeInterval(oneMonthTime)
            }

            return cookie
        }
        
        var services = Services.default()
        services.register(m, name: "m", supports: [Middleware.self])
        
        let drop = try Droplet(config, services)
        
        drop.get("should-set-expiry") { req in
            req.storage["session_expiry"] = true
            try req.assertSession().data.set("foo", to: "bar")
            return "should expire"
        }
        
        let req = Request(method: .get, path: "should-set-expiry")
        let res = try drop.respond(to: req)
        
        guard let cookieIndex = res.cookies.index(of: cookieName) else {
            XCTFail("No cookie")
            return
        }
        
        let cookie = res.cookies.cookies[cookieIndex]
        
        XCTAssertNotNil(cookie.expires)
    }
    
    static let allTests = [
        ("testExample", testExample),
        ("testCustomCookieFactoryWithExpiryDate", testCustomCookieFactoryWithExpiryDate),
    ]
}
