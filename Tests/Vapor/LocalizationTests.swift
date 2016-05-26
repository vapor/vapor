import XCTest
@testable import Vapor

class LocalizationTests: XCTestCase {
    static var allTests: [(String, (LocalizationTests) -> () throws -> Void)] {
        return [
           ("testSimple", testSimple)
        ]
    }

    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    lazy var localization: Localization = Localization(workingDirectory: self.workDir)

    func testSimple() {
        let english = localization["en", "welcome-text"]
        XCTAssert(english == "Welcome to Vapor")

        let spanish = localization["es", "welcome-text"]
        XCTAssert(spanish == "Bienvenidos a Vapor")

        let languagesThatDontExist = ["da", "de", "fr", "th"]

        let transformations = languagesThatDontExist
            .map { languageCode in
                return localization[languageCode, "welcome-text"]
            }
            .filter { $0 != "Welcome to Defaults" }

        XCTAssert(transformations.count == 0, "localization defaults not working properly")

        let notExist = localization["en", "unknown key"]
        XCTAssert(notExist == "unknown key")
	}
}
