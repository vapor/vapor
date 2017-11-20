import XCTest
import Console

class ConsoleTests: XCTestCase {
    func testAsk() throws {
        let console = TestConsole()

        let name = "Test Name"
        let question = "What is your name?"

        console.input = name

        let response = console.ask(question)

        XCTAssertEqual(response, name)
        XCTAssertEqual(console.output, question + "\n> ")
    }

    func testConfirm() throws {
        let console = TestConsole()

        let name = "y"
        let question = "Do you want to continue?"

        console.input = name

        let response = try console.confirm(question)

        XCTAssertEqual(response, true)
        XCTAssertEqual(console.output, question + "\ny/n> ")
    }

    static let allTests = [
        ("testAsk", testAsk),
        ("testConfirm", testConfirm),
    ]
}
