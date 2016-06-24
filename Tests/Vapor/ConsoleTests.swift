import XCTest
@testable import Vapor

class ConsoleTests: XCTestCase {
    static let allTests = [
        ("testCommandRun", testCommandRun),
        ("testCommandInsufficientArgs", testCommandInsufficientArgs),
        ("testCommandFetchArgs", testCommandFetchArgs),
        ("testCommandFetchOptions", testCommandFetchOptions),
        ("testDefaultServe", testDefaultServe),
    ]

    func testCommandRun() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/exe", "test-1"])

        app.commands = [
            TestOneCommand.self
        ]

        do {
            try app.execute().run()
            XCTAssert(console.input() == "Test 1 Ran", "Command 1 did not run")
        } catch {
            XCTFail("Command 1 failed: \(error)")
        }
    }

    func testCommandInsufficientArgs() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/exe", "test-2"])

        app.commands = [
            TestTwoCommand.self
        ]

        let commandTwoSignature = TestTwoCommand.signature()

        XCTAssert(commandTwoSignature == "test-2 <arg-1> {--opt-1} {--opt-2}", "Signature did not match")

        do {
            try app.execute().run()
            XCTFail("Command 2 did not fail")
        } catch {
            //
            XCTAssert(console.input() == commandTwoSignature, "Did not print signature")
        }
    }

    func testCommandFetchArgs() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/ext", "test-2", "123"])

        app.commands = [
            TestTwoCommand.self
        ]

        do {
            try app.execute().run()
            XCTAssert(console.input() == "123", "Did not print 123")
        } catch {
            XCTFail("Command 2 failed to run: \(error)")
        }
    }


    func testCommandFetchOptions() {
        let console = TestConsoleDriver()
        let app = Application(console: console, arguments: ["/path/to/ext", "test-2", "123", "--opt-1=abc"])

        app.commands = [
            TestTwoCommand.self
        ]

        do {
            try app.execute().run()
            XCTAssert(console.input() == "123abc", "Did not print 123abc")
        } catch {
            XCTFail("Command 2 failed to run: \(error)")
        }
    }

    func testDefaultServe() {
        final class TestServe: Command {
            static let id: String = "serve"
            let app: Application
            static var ran = false

            init(app: Application) {
                self.app = app
            }

            func run() {
                TestServe.ran = true
            }
        }

        let app = Application(arguments: ["/path/to/exec"])
        app.commands = [TestServe.self]

        do {
            try app.execute().run()
            XCTAssert(TestServe.ran, "Serve did not default")
        } catch {
            XCTFail("Serve did not default: \(error)")
        }
    }
}

final class TestOneCommand: Command {
    static let id: String = "test-1"
    let app: Application
    var counter = 0

    init(app: Application) {
        self.app = app
    }

    func run() throws {
        print("Test 1 Ran")
    }
}

final class TestTwoCommand: Command {
    static let id: String = "test-2"
    let app: Application

    static let signature: [Signature] = [
        Argument("arg-1"),
        Option("opt-1"),
        Option("opt-2")
    ]

    init(app: Application) {
        self.app = app
    }

    func run() throws {
        let arg1 = try argument("arg-1").string ?? ""
        print(arg1)

        let opt1 = option("opt-1").string ?? ""
        print(opt1)
    }
}

class TestConsoleDriver: Console {
    var buffer: Data

    init() {
        buffer = []
    }

    func output(_ string: String, style: ConsoleStyle, newLine: Bool) {
        buffer.bytes += string.data.bytes
    }

    func input() -> String {
        let string = String(buffer)
        buffer = []
        return string
    }
}
