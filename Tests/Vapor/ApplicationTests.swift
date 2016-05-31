import XCTest
@testable import Vapor

class ApplicationTests: XCTestCase {
    static var allTests: [(String, (ApplicationTests) -> () throws -> Void)] {
        return [
            ("testMediaType", testMediaType),
        ]
    }

    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    /**
        Ensures requests to files like CSS
        files have appropriate "Content-Type"
        headers returned.
    */
    func testMediaType() {
        let app = Application(workDir: workDir)

        let request = Request(method: .get, path: "/styles/app.css")

        guard let response = try? app.respond(to: request) else {
            XCTFail("App could not respond")
            return
        }

        var found = false
        for header in response.headers {
            guard header.key == "Content-Type" else { continue }
            guard header.value == "text/css" else { continue }
            found = true
        }

        XCTAssert(found, "CSS Content Type not found")
    }

 }
