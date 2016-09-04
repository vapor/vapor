import XCTest
import Node
@testable import Settings

class EnvTests: XCTestCase {
    static let allTests = [
        ("testEnv", testEnv),
        ("testBasicEnv", testBasicEnv),
        ("testDefaults", testDefaults),
        ("testNoEnv", testNoEnv),
        ("testEmpty", testEmpty),
        ("testEnvArray", testEnvArray),
    ]
    
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
