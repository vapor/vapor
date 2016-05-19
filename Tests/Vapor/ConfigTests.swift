import XCTest
@testable import Vapor

class ConfigTests: XCTestCase {
    static var allTests: [(String, ConfigTests -> () throws -> Void)] {
        return [
           ("testSimple", testSimple),
           ("testNesting", testNesting),
           ("testEnvironmentCascading", testEnvironmentCascading),
           ("testEnvironmentCascadingNesting", testEnvironmentCascadingNesting),
           ("testDotEnv", testDotEnv),
        ]
    }

    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    func testSimple() {
        let config = Config(workingDirectory: workDir, environment: .Development)
		XCTAssert(config["app", "debug"].bool == true, "Config incorrectly loaded.")
	}

	func testNesting() {
        let config = Config(workingDirectory: workDir, environment: .Development)
		XCTAssert(config["app", "nested", "c", "true"].bool == true, "Nesting config incorrectly loaded.")
	}

	func testEnvironmentCascading() {
        let config = Config(workingDirectory: workDir, environment: .Production)
		XCTAssert(config["app", "debug"].bool == false, "Cascading config incorrectly loaded.")
	}

	func testEnvironmentCascadingNesting() {
        let config = Config(workingDirectory: workDir, environment: .Production)
		XCTAssert(config["app", "nested", "c", "true"].bool == false, "Nesting config incorrectly loaded.")
	}

	func testDotEnv() {
        let config = Config(workingDirectory: workDir, environment: .Development)
		XCTAssert(config["app", "port"].int == 9000, ".env config incorrectly loaded.")
	}
}
