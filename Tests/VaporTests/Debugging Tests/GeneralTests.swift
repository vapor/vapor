import XCTest
@testable import Vapor

class GeneralTests: XCTestCase {
    func testBulletedList() {
        let todos = [
            "Get groceries",
            "Walk the dog",
            "Change oil in car",
            "Get haircut"
        ]

        let bulleted = todos.bulletedList
        let expectation = "\n- Get groceries\n- Walk the dog\n- Change oil in car\n- Get haircut"
        XCTAssertEqual(bulleted, expectation)
    }

    func testMinimumConformance() {
        let minimum = MinimumError.alpha
        let description = minimum.debugDescription
        let expectation = "⚠️ MinimumError: Not enabled\n- id: MinimumError.alpha\n"
        XCTAssertEqual(description, expectation)
    }

    static let allTests = [
        ("testBulletedList", testBulletedList),
        ("testMinimumConformance", testMinimumConformance),
    ]
}
