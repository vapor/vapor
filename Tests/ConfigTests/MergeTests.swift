import XCTest
import Node
@testable import Config

class MergeTests: XCTestCase {
    var configDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Config/TestFiles"
        return path
    }

    func testFile() {
        Node.make(configDirectory: configDir)
    }

    func testMerge() throws {
        let a: Node = [
            "name": "a"
        ]

        let b: Node = [
            "name": "b",
            "nest": [
                "key": "*"
            ]
        ]

        let c: Node = [
            "name": "c",
            "nest": [
                "key": "&",
                "additional": "here"
            ]
        ]

        let merged = Node.merge(prioritized: [("app", a), ("app", b), ("app", c)])
        let expectation: Node = [
            "app": [
                "name": "a",
                "nest": [
                    "key": "*",
                    "additional": "here"
                ]
            ]
        ]
        XCTAssertEqual(merged, expectation)
    }

    func testCLI() throws {
        let arguments = ["--config:app.name=a", "--config:app.friend.name=b", "--config:app.friend.age=37"]
        let cli = Node.makeCLIConfig(arguments: arguments)
        let expectation: Node = [
            "app": [
                "name": "a",
                "friend": [
                    "name": "b",
                    "age": "37"
                ]
            ]
        ]
        XCTAssertEqual(cli, expectation)
    }
}
