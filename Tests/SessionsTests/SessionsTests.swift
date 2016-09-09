import XCTest
@testable import Sessions
import Vapor
import HTTP
import Core

class SessionsTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample),
    ]

    func testExample() throws {
        let s = MemorySessions()
        let m = SessionsMiddleware(sessions: s)
        let drop = Droplet(availableMiddleware: ["sessions": m])

        drop.get("set") { req in
            try req.session().data["foo"] = "bar"
            try req.session().data["bar"] = "baz"
            return "set"
        }

        drop.get("get") { req in
            return try req.session().data["foo"]?.string ?? "fail"
        }

        let req = Request(method: .get, path: "set")
        let res = try drop.respond(to: req)

        guard let c = res.cookies["vapor-sessions"] else {
            XCTFail("No cookie")
            return
        }

        XCTAssertEqual(s.sessions[c], Node([
            "foo": "bar",
            "bar": "baz"
        ]))

        let req2 = Request(method: .get, path: "get")
        req2.cookies["vapor-sessions"] = c
        let res2 = try drop.respond(to: req2)

        XCTAssertEqual(res2.body.bytes?.string, "bar")
    }

}
