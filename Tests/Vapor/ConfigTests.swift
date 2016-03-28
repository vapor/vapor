import XCTest
@testable import Vapor

class ConfigTests: XCTestCase {
    static var allTests : [(String, ConfigTests -> () throws -> Void)] {
        return [
           ("testSimple", testSimple),
           ("testNesting", testNesting),
           ("testEnvironmentCascading", testEnvironmentCascading),
           ("testEnvironmentCascadingNesting", testEnvironmentCascadingNesting),
           ("testDotEnv", testDotEnv),
        ]
    }
    
    #if Xcode
    let workDir = "/Users/tanner/Developer/vapor/vapor/Sources/VaporDev/"
    #else
    let workDir = "Sources/VaporDev/"
    #endif

	func testSimple() {
		let config = self.config(.Development)
		XCTAssert(config.get("app.debug", false) == true, "Config incorrectly loaded.")
	}

	func testNesting() {
		let config = self.config(.Development)
		XCTAssert(config.get("app.nested.c.true", false) == true, "Nesting config incorrectly loaded.")
	}

	func testEnvironmentCascading() {
		let config = self.config(.Production)
		XCTAssert(config.get("app.debug", true) == false, "Cascading config incorrectly loaded.")
	}

	func testEnvironmentCascadingNesting() {
		let config = self.config(.Production)
		XCTAssert(config.get("app.nested.c.true", true) == false, "Nesting config incorrectly loaded.")
	}

	func testDotEnv() {
		let config = self.config(.Development)
		XCTAssert(config.get("app.port", 0) == 9000, ".env config incorrectly loaded.")
	}

	private func config(environment: Environment) -> Config {
		let app = self.app(environment)
        
        print(workDir)

		do {
			try app.config.populate("\(workDir)Config", application: app)
		} catch {
			XCTAssert(false, "Failed to load config: \(error)")
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