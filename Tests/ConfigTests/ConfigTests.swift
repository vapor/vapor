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
