import XCTest
import Node
@testable import Settings

class CLIConfigTests: XCTestCase {
    static let allTests = [
        ("testCLI", testCLI),
        ("testBools", testBools),
    ]

    func testCLI() throws {
        let arguments = [
            "--config:app.name=a",
            "--config:app.friend.name=b",
            "--config:app.friend.age=37",
            "--config:name=world",
            "--config:bools.yes"
        ]
        let cli = Node.makeCLIConfig(arguments: arguments)
        let expectation: Node = [
            "app": [
                "name": "a",
                "friend": [
                    "name": "b",
                    "age": "37"
                ]
            ],
            "name": "world",
            "bools": [
                "yes": "true"
            ]
        ]
        XCTAssertEqual(cli, expectation)
    }

    func testBools() {
        let arguments = [
            "--config:bools.yes"
        ]
        let cli = Node.makeCLIConfig(arguments: arguments)
        let expectation: Node = [
            "bools": [
                "yes": "true"
            ]
        ]
        XCTAssertEqual(cli, expectation)
    }
}
