import XCTest
import Node
@testable import Config

var configDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/../../Sources/Config/TestFiles"
    return path
}

class EnvTests: XCTestCase {
    func testBasicEnv() {
        Env.set("TEST_ENV_KEY", value: "name")
        Env.set("TEST_ENV_VALUE", value: "World")
        defer {
            Env.remove("TEST_ENV_KEY")
            Env.remove("TEST_ENV_VALUE")
        }

        let node: Node = [
            "$TEST_ENV_KEY": "$TEST_ENV_VALUE"
        ]
        let expectation: Node = [
            "name": "World"
        ]

        XCTAssertEqual(node.loadEnv(), expectation)
    }

    func testDefaults() {
        let node: Node = [
            "port": "$NO_EXIST:8080"
        ]
        let expectation: Node = [
            "port": "8080"
        ]

        XCTAssertEqual(node.loadEnv(), expectation)
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
