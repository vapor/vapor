import XCTest
@testable import Vapor

class ErrorTests: XCTestCase {
    static let allTests = [
        ("testFixes", testFixes)
    ]

    func testFixes() throws {
        let error = ErrorView()
        let result = error.render(code: 404, message: "Not found!").string
        XCTAssert(result.contains("404"))
        XCTAssert(result.contains("Not found!"))
    }
}
