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
}


/*

class ConfigTests: XCTestCase {
    static let allTests = [
       ("testSimple", testSimple),
       ("testNesting", testNesting),
       ("testEnvironmentCascading", testEnvironmentCascading),
       ("testEnvironmentCascadingNesting", testEnvironmentCascadingNesting),
       ("testConfigKeys", testConfigKeys),
       ("testConfigParsing", testConfigParsing),
    ]

    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    func testSimple() throws {
        let config = try Config(workingDirectory: workDir, environment: .development)
		XCTAssert(config["app", "debug"].bool == true, "Config incorrectly loaded.")
	}

	func testNesting() throws {
        let config = try Config(workingDirectory: workDir, environment: .development)
		XCTAssert(config["app", "nested", "c", "true"].bool == true, "Nesting config incorrectly loaded.")
	}

	func testEnvironmentCascading() throws {
        let config = try Config(workingDirectory: workDir, environment: .production)
		XCTAssert(config["app", "debug"].bool == false, "Cascading config incorrectly loaded.")
	}

	func testEnvironmentCascadingNesting() throws {
        let config = try Config(workingDirectory: workDir, environment: .production)
		XCTAssert(config["app", "nested", "c", "true"].bool == false, "Nesting config incorrectly loaded.")
	}

    func testConfigKeys() {
        guard let (complexFile, complexPath) = Config.parseConfigKey("--config:file.path.to.value") else {
            XCTFail("Couldn't extract complex cli config")
            return
        }
        XCTAssert(complexFile == "file")
        XCTAssert(complexPath.map { "\($0)" } == ["path", "to", "value"])

        guard let (simpleFile, simplePath) = Config.parseConfigKey("--some-key") else {
            XCTFail("Couldn't extract simple cli config")
            return
        }
        XCTAssert(simpleFile == "app")
        XCTAssert(simplePath.map { "\($0)" } == ["some-key"])
    }

    func testConfigParsing() {
        // If a flag has leading `--` and no `=`, it's implicitly `true`
        guard let (key, value) = Config.parseArgument("--release") else {
            XCTFail("Couldn't parse boolean key")
            return
        }

        XCTAssert(key == "--release")
        XCTAssert(value == "true")
    }
}
*/
