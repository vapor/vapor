import XCTest
import Command

class CommandTests: XCTestCase {
    func testExample() throws {
        let console = TestConsole()
        let group = TestGroup()

        try! console.run(group, arguments: ["vapor", "sub", "test", "--help"])
        print(console.output)
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
