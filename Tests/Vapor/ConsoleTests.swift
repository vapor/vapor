import XCTest
@testable import Vapor

class ConsoleTests: XCTestCase {
    static var allTests: [(String, (ConsoleTests) -> () throws -> Void)] {
        return [
            ("testDefaultServe", testDefaultServe)
        ]
    }

    func testDefaultServe() {
        let args = ["/Path/To/Executable", "--port=8001", "--env=production"]
        let app = Application()
        let (command, arguments) = app.extract(fromInput: args)
        XCTAssert(command == Serve.self)
        print(arguments)
        XCTAssert(arguments.isEmpty)
    }
}
