import XCTest
import SourceKit

class SourceKitTests: XCTestCase {
    func testExample() throws {
        let file = try Library.shared.parseFile(at: "/Users/tanner/dev/tanner0101/sourcekit/Sources/SourceKit/Test.swift")

        for c in file.structures {
            print("Structure: \(c.name)")
            print(c.inheritedTypes)
            for prop in c.subStructures {
                print(prop.name)
                print(prop.comments)
                print()
            }
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
