import XCTest
@testable import Vapor

#if os(Linux)
	extension ConfigTests: XCTestCaseProvider {
		var allTests : [(String, () throws -> Void)] {
			return [
				("testSimple", testSimple),
				("testNesting", testNesting),
				("testEnvironmentCascading", testEnvironmentCascading),
				("testEnvironmentCascadingNesting", testEnvironmentCascadingNesting),
			]
		}
	}
#endif

class ConfigTests: XCTestCase {

	func testSimple() {
		let config = self.config(.Development)
		XCTAssert(config.get("app.debug")?.bool == true, "Config incorrectly loaded.")
	}

	func testNesting() {
		let config = self.config(.Development)
		XCTAssert(config.get("app.nested.c.true")?.bool == true, "Nesting config incorrectly loaded.")
	}

	func testEnvironmentCascading() {
		let config = self.config(.Production)
		XCTAssert(config.get("app.debug")?.bool == false, "Cascading config incorrectly loaded.")
	}

	func testEnvironmentCascadingNesting() {
		let config = self.config(.Production)
		XCTAssert(config.get("app.nested.c.true")?.bool == false, "Nesting config incorrectly loaded.")
	}

	private func config(environment: Environment) -> Config {
		let app = self.app(environment)

		do {
			try app.config.populate("./TestConfig", application: app)
		} catch {
			XCTAssert(false, "Failed to load config: \(config)")
		}

		return app.config
	}

	private func app(environment: Environment) -> Application {
		let app = Application()

		app.detectEnvironmentHandler = { _ in
			return environment
		}

		return app
	}

}