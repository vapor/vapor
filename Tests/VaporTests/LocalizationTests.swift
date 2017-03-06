import XCTest
@testable import Vapor

class LocalizationTests: XCTestCase {
    static let allTests = [
       ("testSimple", testSimple)
    ]

    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    lazy var localization: Localization = try! Localization(localizationDirectory: self.workDir + "Localization/")

    func testSimple() {
        print("Localization: \(localization)")
        // Basic language tests
        XCTAssertEqual(localization["en", "welcome", "title"], "Welcome to Vapor!")
        XCTAssertEqual(localization["es", "welcome", "title"], "¡Bienvenidos a Vapor!")
        
        // Test default locale when unsupported elsewhere
        XCTAssertEqual(localization["en", "other-key"], "☁️")

        // Test non-existent langauges
        let languagesThatDontExist = ["da", "de", "fr", "th"]

        let transformations = languagesThatDontExist
            .map { languageCode in
                return localization[languageCode, "welcome", "title"]
            }
            .filter { $0 != "Default Welcome Message" }

        XCTAssert(transformations.count == 0, "localization defaults not working properly")

        let notExist = localization["en", "unknown", "key"]
        XCTAssertEqual(notExist, "unknown.key")
	}
}
