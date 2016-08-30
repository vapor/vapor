import XCTest
import Node
@testable import Config

var configDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/../../Sources/Config/TestFiles"
    return path
}

class CLIConfigTests: XCTestCase {
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
        print(cli)
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
        print(cli)
        XCTAssertEqual(cli, expectation)
    }
}

class MergeTests: XCTestCase {
    func testFile() throws {
        let node = try Node.makeConfig(directory: configDir)
        let expectation: Node = [
            "test": [
                "name": "a"
            ],
            "file.hello": .bytes("Hello!\n".bytes)
        ]
        XCTAssertEqual(node, expectation)
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

        let node = try Node.makeConfig(
            prioritized: [
                .memory(name: "app", config: a),
                .memory(name: "app", config: b),
                .memory(name: "app", config: c)
            ]
        )
        let expectation: Node = [
            "app": [
                "name": "a",
                "nest": [
                    "key": "*",
                    "additional": "here"
                ]
            ]
        ]
        XCTAssertEqual(node, expectation)
    }
}
