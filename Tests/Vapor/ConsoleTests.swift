import XCTest
@testable import Vapor

class ConsoleTests: XCTestCase {
    static var allTests: [(String, (ConsoleTests) -> () throws -> Void)] {
        return [
            ("testCommandRun", testCommandRun),
            ("testCommandInsufficientArgs", testCommandInsufficientArgs),
            ("testCommandFetchOptions", testCommandFetchOptions),
            ("testDefaultServe", testDefaultServe),
        ]
    }

    func testCommandRun() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/exe", "test-1"])

        let commandOne = TestOneCommand(app: app)

        app.commands = [
            commandOne,
        ]

        do {
            try app.execute()
            XCTAssert(console.input() == "Test 1 Ran", "Command 1 did not run")
        } catch {
            XCTFail("Command 1 failed: \(error)")
        }
    }

    func testCommandInsufficientArgs() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/exe", "test-2"])

        let commandTwo = TestTwoCommand(app: app)

        app.commands = [
            commandTwo
        ]

        commandTwo.printSignature()
        let commandTwoSignature = console.input()

        XCTAssert(commandTwoSignature == "test-2 <arg-1> {--opt-1} {--opt-2}", "Signature did not match")

        do {
            try app.execute()
            XCTFail("Command 2 did not fail")
        } catch {
            //
            XCTAssert(console.input() == commandTwoSignature, "Did not print signature")
        }
    }

    func testCommandFetchArgs() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/ext", "test-2", "123"])

        let commandTwo = TestTwoCommand(app: app)

        app.commands = [
            commandTwo
        ]

        do {
            try app.execute()
            XCTAssert(console.input() == "123", "Did not print 123")
        } catch {
            XCTFail("Command 2 failed to run: \(error)")
        }
    }


    func testCommandFetchOptions() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/ext", "test-2", "123", "--opt-1=abc"])

        let commandTwo = TestTwoCommand(app: app)

        app.commands = [
            commandTwo
        ]

        do {
            try app.execute()
            XCTAssert(console.input() == "123abc", "Did not print 123abc")
        } catch {
            XCTFail("Command 2 failed to run: \(error)")
        }
    }

    func testDefaultServe() {
        class TestServe: Command {
            let id: String = "serve"
            let app: Application
            var ran = false

            init(app: Application) {
                self.app = app
            }

            func run() {
                ran = true
            }
        }

        let app = Application()
        let serve = TestServe(app: app)
        app.commands = [serve]

        do {
            try app.execute()
            XCTAssert(serve.ran, "Serve did not default")
        } catch {
            XCTFail("Serve did not default: \(error)")
        }
    }
}

class TestOneCommand: Command {
    let id: String
    let app: Application
    var counter = 0

    init(app: Application) {
        id = "test-1"
        self.app = app
    }

    func run() {
        print("Test 1 Ran")
    }
}

class TestTwoCommand: Command {
    let id: String
    let app: Application

    let options = [
        Option("opt-1"),
        Option("opt-2")
    ]

    let arguments = [
        Argument("arg-1")
    ]

    init(app: Application) {
        id = "test-2"
        self.app = app
    }

    func run() {
        let arg1 = argument("arg-1").string ?? ""
        print(arg1)

        let opt1 = option("opt-1").string ?? ""
        print(opt1)
    }
}

class TestConsoleDriver: ConsoleDriver {
    var buffer: Data

    init() {
        buffer = []
    }

    func output(_ string: String, style: Console.Style, newLine: Bool) {
        buffer.bytes += string.data.bytes
    }

    func input() -> String {
        let string = String(buffer)
        buffer = []
        return string
    }

    func exit(code: Int) {
        print("Exiting with code \(code)")
    }
}
