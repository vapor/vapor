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
		let config = makeConfig(.Development, workDir: workDir)
		XCTAssert(config["app", "debug"].bool == true, "Config incorrectly loaded.")
	}

	func testNesting() {
		let config = makeConfig(.Development, workDir: workDir)
		XCTAssert(config["app", "nested", "c", "true"].bool == true, "Nesting config incorrectly loaded.")
	}

	func testEnvironmentCascading() {
		let config = makeConfig(.Production, workDir: workDir)
		XCTAssert(config["app", "debug"].bool == false, "Cascading config incorrectly loaded.")
	}

	func testEnvironmentCascadingNesting() {
		let config = makeConfig(.Production, workDir: workDir)
		XCTAssert(config["app", "nested", "c", "true"].bool == false, "Nesting config incorrectly loaded.")
	}

	func testDotEnv() {
		let config = makeConfig(.Development, workDir: workDir)
		XCTAssert(config["app", "port"].int == 9000, ".env config incorrectly loaded.")
	}
}

/**
 Global functions because any function that takes an argument on an XCTest class fails on Linux.
 */

private func makeConfig(_ environment: Environment, workDir: String) -> Config {
    return Config.init(workingDirectory: workDir, environment: environment)
//    let app = makeApp(environment)
//
//    do {
//        try app.config.populate("\(workDir)Config", application: app)
//    } catch {
//        XCTAssert(false, "Failed to load config: \(error)")
//    }
//
//    return app.config
}

//private func makeApp(_ environment: Environment) -> Application {
//    let app = Application()
//
//    app.detectEnvironmentHandler = { _ in
//        return environment
//    }
//
//    return app
//}
