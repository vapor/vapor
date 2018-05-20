import XCTest
@testable import Vapor

class ConfigIntegrationTests: XCTestCase {
    static let allTests = [
       ("testSimple", testSimple),
       ("testNesting", testNesting),
       ("testEnvironmentCascading", testEnvironmentCascading),
       ("testEnvironmentCascadingNesting", testEnvironmentCascadingNesting),
    ]

    var workDir: String {
        #if swift(>=4.0)
        let parent = #file.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        #else
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        #endif
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    func testSimple() throws {
        let config = try Node.makeTestConfig(workDir: workDir, env: .development)
        XCTAssert(config["app", "debug"]?.bool == true, "Config incorrectly loaded.")
	}

    func testNesting() throws {
        let config = try Node.makeTestConfig(workDir: workDir, env: .development)
		XCTAssert(config["app", "nested", "c", "true"]?.bool == true, "Nesting config incorrectly loaded.")
	}

    func testEnvironmentCascading() throws {
        let config = try Node.makeTestConfig(workDir: workDir, env: .production)
		XCTAssert(config["app", "debug"]?.bool == false, "Cascading config incorrectly loaded.")
	}

    func testEnvironmentCascadingNesting() throws {
        let config = try Node.makeTestConfig(workDir: workDir, env: .production)
		XCTAssert(config["app", "nested", "c", "true"]?.bool == false, "Nesting config incorrectly loaded.")
	}
}

extension Node {
    static func makeTestConfig(workDir: String, env: Environment) throws -> Config {
        let configDirectory = workDir.finished(with: "/") + "Config/"
        return try Config(
            prioritized: [
                .commandLine,
                .directory(root: configDirectory + "secrets"),
                .directory(root: configDirectory + env.description),
                .directory(root: configDirectory)
            ]
        )
    }
}
