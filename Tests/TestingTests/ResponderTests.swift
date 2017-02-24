import Vapor
import HTTP
import Testing
import XCTest


class ResponderTests: XCTestCase {
    override func setUp() {
        //Testing.onFail = XCTFail
    }

    func testSee() throws {
        let drop = try Droplet()
        drop.get("foo") { req in
            return "bar"
        }

        try drop.testResponse(to: .get, at: "foo")
            .assertBody(contains: "bar")
            .assertStatus(is: .ok)
            .assertHeader(.contentType, contains: "text/plain")
    }

    static let allTests = [
        ("testSee", testSee)
    ]
}
