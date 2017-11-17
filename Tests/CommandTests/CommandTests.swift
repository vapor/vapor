import XCTest
import Command
import Console

class CommandTests: XCTestCase {
    func testExample() throws {
        let console = Terminal()
        let group = TestGroup()

        try! console.run(group, arguments: ["vapor", "sub", "test", "--help"])
        print(console.output)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
