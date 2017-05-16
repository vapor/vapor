import XCTest
@testable import Vapor
import HTTP
import Console

class ErrorTests: XCTestCase {
    static let allTests = [
        ("testFixes", testFixes)
    ]

    func testFixes() throws {
        let log = ConsoleLogger(Terminal(arguments: []))
        let req = Request(method: .get, uri: "foo", headers: ["Accept": "html"])
        let view = ErrorMiddleware(.development, log).make(with: req, for: Abort(.notFound))
        
        XCTAssert(try view.bodyString().contains("404"))
        XCTAssert(try view.bodyString().contains("Not Found"))
    }
}
