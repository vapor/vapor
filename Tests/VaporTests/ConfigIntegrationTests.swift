import XCTest
@testable import Vapor
import Configs

class ConfigIntegrationTests: XCTestCase {
    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    func testSimple() throws {
        let config = try Config.makeTestConfig(workDir: workDir, env: .development)
        XCTAssert(config["app", "debug"]?.bool == true, "Config incorrectly loaded.")
	}

    func testNesting() throws {
        let config = try Config.makeTestConfig(workDir: workDir, env: .development)
		XCTAssert(config["app", "nested", "c", "true"]?.bool == true, "Nesting config incorrectly loaded.")
	}

    func testEnvironmentCascading() throws {
        let config = try Config.makeTestConfig(workDir: workDir, env: .production)
		XCTAssert(config["app", "debug"]?.bool == false, "Cascading config incorrectly loaded.")
	}

    func testEnvironmentCascadingNesting() throws {
        let config = try Config.makeTestConfig(workDir: workDir, env: .production)
		XCTAssert(config["app", "nested", "c", "true"]?.bool == false, "Nesting config incorrectly loaded.")
	}
    
    static let allTests = [
        ("testSimple", testSimple),
        ("testNesting", testNesting),
        ("testEnvironmentCascading", testEnvironmentCascading),
        ("testEnvironmentCascadingNesting", testEnvironmentCascadingNesting),
    ]
}

extension Config {
    static func makeTestConfig(workDir: String, env: Environment) throws -> Config {
        let configDirectory = workDir.finished(with: "/") + "Config/"
        return try Config.fromFiles(environment: env, at: configDirectory)
    }
}
