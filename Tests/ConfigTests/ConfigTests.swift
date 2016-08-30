import XCTest
import Node
@testable import Config

class EnvTests: XCTestCase {
    func testEnv() {
        let TEST_KEY = "TEST_ENV_VALUE"
        XCTAssertEqual(Env.get(TEST_KEY), nil)
        defer {
            Env.remove(TEST_KEY)
            XCTAssertEqual(Env.get(TEST_KEY), nil)
        }

        Env.set(TEST_KEY, value: "Hello!")
        XCTAssertEqual(Env.get(TEST_KEY), "Hello!")

        Env.set(TEST_KEY, value:"Aloha!")
        XCTAssertEqual(Env.get(TEST_KEY), "Aloha!")

        Env.set(TEST_KEY, value: "Hola!", replace: false)
        XCTAssertEqual(Env.get(TEST_KEY), "Aloha!")
    }

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

        XCTAssertEqual(node.hydratedEnv(), expectation)
    }

    func testDefaults() {
        let node: Node = [
            "port": "$NO_EXIST:8080"
        ]
        let expectation: Node = [
            "port": "8080"
        ]

        XCTAssertEqual(node.hydratedEnv(), expectation)
    }

    func testNoEnv() {
        let node: Node = ["key": "$I_NO_EXIST"]
        let env = node.hydratedEnv()
        XCTAssertNil(env)
    }

    func testEmpty() {
        let node: Node = [:]
        let env = node.hydratedEnv()
        XCTAssertEqual(env, [:])
    }

    func testEnvArray() {
        let TEST_KEY = "TEST_ENV_KEY"
        Env.set(TEST_KEY, value: "Hello!")
        defer { Env.remove(TEST_KEY) }
        let array: Node = [ Node("$\(TEST_KEY)"), Node("$\(TEST_KEY)")]
        let env = array.hydratedEnv()
        let expectation: Node = ["Hello!", "Hello!"]
        XCTAssertEqual(env, expectation)
    }
}

class ConfigTests: XCTestCase {
    func testLoad() throws {
        let config = try Node.makeConfig(
            prioritized: [
                .directory(root: configDir.finished(with: "/") + "inner"),
                .directory(root: configDir)
            ]
        )
        let expectation: Node = [
            "test": [
                "name": "inner/test"
            ],
            "file.hello": .bytes("Hello!\n".bytes)
        ]
        XCTAssertEqual(config, expectation)
    }

    func testExample() throws {
        let config = try Node.makeConfig(
            prioritized: [
                .memory(name: "app", config: ["port": 8080]),
                .commandLine
            ]
        )

        let expectation: Node = [
            "app": [
                "port": 8080
            ]
        ]
        XCTAssertEqual(config, expectation)
    }

    func testEmpty() throws {
        let config = try Node.makeConfig(
            prioritized: [
                .directory(root: "i/dont/exist")
            ]
        )
        XCTAssertEqual(config, [:])
    }
}
