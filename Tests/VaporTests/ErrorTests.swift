import XCTest
@testable import Vapor

class ErrorTests: XCTestCase {
    static let allTests = [
        ("testFixes", testFixes)
    ]

    func testFixes() throws {
        let drop = try Droplet()
        let view = drop.view.make(Abort(.notFound))
        print(view.data.makeString())
        XCTAssert(view.data.makeString().contains("404"))
        XCTAssert(view.data.makeString().contains("Not Found"))
    }
}
