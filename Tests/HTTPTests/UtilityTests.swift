@testable import HTTP
import XCTest

class UtilityTests : XCTestCase {
    func testRFC1123() {
        guard let date = RFC1123().formatter.date(from: "Fri, 12 Feb 2010 05:23:03 GMT") else {
            XCTFail()
            return
        }
        
        let string = RFC1123().formatter.string(from: date)
        
        XCTAssertEqual(string, "Fri, 12 Feb 2010 05:23:03 GMT")
    }
    
    func HTTPURIs() {
        XCTAssertEqual(URI.defaultPorts["ws"], 80)
        XCTAssertEqual(URI.defaultPorts["wss"], 443)
        XCTAssertEqual(URI.defaultPorts["http"], 80)
        XCTAssertEqual(URI.defaultPorts["https"], 443)
    }
    
    func testMethod() {
        XCTAssertEqual(HTTPMethod.get, "GET")
        XCTAssertEqual(HTTPMethod.post, HTTPMethod("post"))
    }
    
    func testCookie() {
        var cookie = Cookie(named: "token", value: "Hello World")
        XCTAssertEqual(cookie.serialized(), "token=Hello World")
        
        cookie = Cookie(from: cookie.serialized())!
        XCTAssertEqual(cookie.name, "token")
        XCTAssertEqual(cookie.value.value, "Hello World")
        
        let date = Date()
        let dateString = RFC1123().formatter.string(from: date)
        
        cookie.value.httpOnly = true
        cookie.value.expires = date
        cookie.value.value = "Test"
        XCTAssertEqual(cookie.serialized(), "token=Test; Expires=\(dateString); HttpOnly")
        
        cookie = Cookie(from: cookie.serialized())!
        XCTAssertEqual(cookie.name, "token")
        XCTAssertEqual(cookie.value.value, "Test")
        XCTAssertEqual(Int(cookie.value.expires?.timeIntervalSince1970 ?? 0), Int(date.timeIntervalSince1970))
        XCTAssertEqual(cookie.value.httpOnly, true)
    }
    
    func testCookies() {
        var cookies: Cookies = [
            "session": "test",
            "token2": "abc123"
        ]
        
        XCTAssertEqual(cookies["session"]?.value, "test")
        XCTAssertNil(cookies["SessioN"]?.value)
        XCTAssertEqual(cookies["token2"]?.value, "abc123")
        
        cookies["token2"] = "123abc"
        XCTAssertEqual(cookies["token2"]?.value, "123abc")
        
        cookies["test"] = "test"
        
        for cookie in cookies {
            XCTAssert(["session", "token2", "test"].contains(cookie.name))
            XCTAssert(["123abc", "test"].contains(cookie.value.value))
        }
        
        XCTAssertEqual(cookies.cookies.count, 3)
    }
    
    static let allTests = [
        ("testRFC1123", testRFC1123),
        ("HTTPURIs", HTTPURIs),
        ("testMethod", testMethod),
        ("testCookie", testCookie),
        ("testCookies", testCookies),
    ]
}
