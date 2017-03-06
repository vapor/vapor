import XCTest
@testable import Vapor

class ErrorTests: XCTestCase {
    static let allTests = [
        ("testFixes", testFixes)
    ]

    func testFixes() throws {
        let drop = try Droplet()
        let view = try drop.view.make(Abort(.notFound))
        XCTAssert(view.data.string.contains("404"))
        XCTAssert(view.data.string.contains("Not found!"))
    }
}
