import Vapor
import HTTP
import Testing

class ResponderTests: XCTestCase {
    func testSee() throws {
        let drop = Droplet()
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
