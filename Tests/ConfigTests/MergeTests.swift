import XCTest
import Node
@testable import Config

var configDir: String {
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    let path = "/\(parent)/../../Sources/Config/TestFiles"
    return path
}

class ENVConfigTests: XCTestCase {
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

    func testNoEnv() {
        let node: Node = ["key": "$I_NO_EXIST"]
        let env = node.loadEnv()
        XCTAssertNil(env)
    }

    func testEmpty() {
        let node: Node = [:]
        let env = node.loadEnv()
        XCTAssertEqual(env, [:])
    }

    func testEnvArray() {
        let TEST_KEY = "TEST_ENV_KEY"
        Env.set(TEST_KEY, value: "Hello!")
        defer { Env.remove(TEST_KEY) }
        let array: Node = [ Node("$\(TEST_KEY)"), Node("$\(TEST_KEY)")]
        let env = array.loadEnv()
        let expectation: Node = ["Hello!", "Hello!"]
        XCTAssertEqual(env, expectation)
    }
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
}
