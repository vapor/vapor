import XCTest
@testable import Vapor
import Engine

class DropletTests: XCTestCase {
    static let allTests = [
        ("testMediaType", testMediaType)
    ]

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
    func testMediaType() throws {
        let drop = Droplet(workDir: workDir)

        let request = try Request(method: .get, uri: "/styles/app.css")

        guard let response = try? drop.respond(to: request) else {
            XCTFail("drop could not respond")
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
