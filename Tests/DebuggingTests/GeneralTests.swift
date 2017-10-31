import XCTest
@testable import Debugging

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

    func testReadableName() {
        let typeName = "SomeRandomModule.MyType.Error"
        let readableName = typeName.readableTypeName()
        let expectation = "My Type Error"
        XCTAssertEqual(readableName, expectation)
    }

    func testReadableNameEdgeCase() {
        let edgeCases = [
            "SomeModule.": "",
            "SomeModule.S": "S"
        ]
        edgeCases.forEach { edgeCase, expectation in
            let readableName = edgeCase.readableTypeName()
            XCTAssertEqual(readableName, expectation)
        }
    }

    func testMinimumConformance() {
        let minimum = MinimumError.alpha
        let description = minimum.debugDescription
        let expectation = "⚠️ Minimum Error: Not enabled\n- id: DebuggingTests.MinimumError.alpha"
        XCTAssertEqual(description, expectation)
    }

    static let allTests = [
        ("testBulletedList", testBulletedList),
        ("testReadableName", testReadableName),
        ("testReadableNameEdgeCase", testReadableNameEdgeCase),
        ("testMinimumConformance", testMinimumConformance),
    ]
}
