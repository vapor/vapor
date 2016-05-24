import XCTest
@testable import Vapor

class ConfigTests: XCTestCase {
    static var allTests: [(String, (ConfigTests) -> () throws -> Void)] {
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
		let config = makeConfig(.Development, workDir: workDir)
		XCTAssert(config.get("app.debug", false) == true, "Config incorrectly loaded.")
	}

	func testNesting() {
		let config = makeConfig(.Development, workDir: workDir)
		XCTAssert(config.get("app.nested.c.true", false) == true, "Nesting config incorrectly loaded.")
	}

	func testEnvironmentCascading() {
		let config = makeConfig(.Production, workDir: workDir)
		XCTAssert(config.get("app.debug", true) == false, "Cascading config incorrectly loaded.")
	}

	func testEnvironmentCascadingNesting() {
		let config = makeConfig(.Production, workDir: workDir)
		XCTAssert(config.get("app.nested.c.true", true) == false, "Nesting config incorrectly loaded.")
	}

	func testDotEnv() {
		let config = makeConfig(.Development, workDir: workDir)
		XCTAssert(config.get("app.port", 0) == 9000, ".env config incorrectly loaded.")
	}
}

/**
 Global functions because any function that takes an argument on an XCTest class fails on Linux.
 */

private func makeConfig(_ environment: Environment, workDir: String) -> Config {
    let app = makeApp(environment)

    do {
        try app.config.populate("\(workDir)Config", application: app)
    } catch {
        XCTAssert(false, "Failed to load config: \(error)")
    }

    return app.config
}

private func makeApp(_ environment: Environment) -> Application {
    let app = Application()

    app.detectEnvironmentHandler = { _ in
        return environment
    }

    return app
}
