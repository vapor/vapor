import XCTest
@testable import Vapor
import HTTP

class ErrorTests: XCTestCase {
    static let allTests = [
        ("testFixes", testFixes)
    ]

    func testFixes() throws {
        let drop = try Droplet()
        let req = try Request(method: .get, uri: "foo", headers: ["Accept": "html"])
        let view = drop.errorRenderer.make(with: req, for: Abort(.notFound))
        XCTAssert(try view.bodyString().contains("404"))
        XCTAssert(try view.bodyString().contains("Not Found"))
    }
}
