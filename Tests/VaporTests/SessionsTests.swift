import XCTest
@testable import Sessions
import Vapor
import HTTP
import Core

class SessionsTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample),
        ("testWithExpiryDate", testWithExpiryDate),
    ]

    func testExample() throws {
        let s = MemorySessions()
        let m = SessionsMiddleware(s)
        let drop = try Droplet(middleware: [m])

        drop.get("set") { req in
            try req.assertSession().data["foo"] = "bar"
            try req.assertSession().data["bar"] = "baz"
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

        for s in s.sessions {
            print(s.key)
            print(s.value.data)
        }
        
        XCTAssertEqual(s.sessions[c]?.data, Node([
            "foo": "bar",
            "bar": "baz"
        ]))

        let req2 = Request(method: .get, path: "get")
        req2.cookies["vapor-session"] = c
        let res2 = try drop.respond(to: req2)

        XCTAssertEqual(res2.body.bytes?.makeString(), "bar")
    }
    
    func testWithExpiryDate() throws {
        let s = MemorySessions()
        let m = SessionsMiddleware(s)
        let drop = try Droplet(middleware: [m])
        
        drop.get("should-set-expiry") { req in
            req.storage["session_expiry"] = true
            try req.assertSession().data["foo"] = "bar"
            return "should expire"
        }
        
        let req = Request(method: .get, path: "should-set-expiry")
        let res = try drop.respond(to: req)
        
        guard let cookieIndex = res.cookies.index(of: "vapor-session") else {
            XCTFail("No cookie")
            return
        }
        
        let cookie = res.cookies.cookies[cookieIndex]
        
        XCTAssertNotNil(cookie.expires)
    }
    
}
