import XCTest
@testable import Vapor
import Console

class ConsoleTests: XCTestCase {
    static let allTests = [
        ("testCommandRun", testCommandRun),
        ("testCommandInsufficientArgs", testCommandInsufficientArgs),
        ("testVersionCommand", testVersionCommand),
        ("testCommandFetchArgs", testCommandFetchArgs),
        ("testCommandFetchOptions", testCommandFetchOptions),
        ("testDefaultServe", testDefaultServe),
    ]

    func testCommandRun() throws {
        let console = TestConsoleDriver()
        let drop = try Droplet(arguments: ["/path/to/exe", "test-1"])

        drop.console = console

        drop.commands = [
            TestOneCommand(console: console)
        ]

        do {
            try drop.runCommands()
            XCTAssert(console.input().contains("Test 1 Ran"), "Command 1 did not run")
        } catch {
            XCTFail("Command 1 failed: \(error)")
        }
    }

    func testCommandInsufficientArgs() throws {
        let console = TestConsoleDriver()
        let drop = try Droplet(arguments: ["/path/to/exe", "test-2"])

        drop.console = console

        let command = TestTwoCommand(console: console)
        drop.commands = [
            command
        ]

        do {
            try drop.runCommands()
            XCTFail("Command 2 did not fail")
        } catch {
            XCTAssert(console.input().contains("Usage: /path/to/exe test-2 <arg-1> [--opt-1] [--opt-2]"), "Did not print signature")
        }
    }

    func testVersionCommand() throws {
        let console = TestConsoleDriver()
        let drop = try Droplet(arguments: ["run", "version"])

        drop.console = console

        let command = VersionCommand(console: console)
        drop.commands = [
            command
        ]
        try drop.runCommands()
        XCTAssert(console.input().contains("Vapor Framework v2."))
    }

    func testCommandFetchArgs() throws {
        let console = TestConsoleDriver()
        let drop = try Droplet(arguments: ["/path/to/ext", "test-2", "123"])

        drop.console = console

        let command = TestTwoCommand(console: console)
        drop.commands = [
            command
        ]

        do {
            try drop.runCommands()
            XCTAssert(console.input().contains("123"), "Did not print 123")
        } catch {
            XCTFail("Command 2 failed to run: \(error)")
        }
    }


    func testCommandFetchOptions() throws {
        let console = TestConsoleDriver()
        let drop = try Droplet(arguments: ["/path/to/ext", "test-2", "123", "--opt-1=abc"])

        drop.console = console

        let command = TestTwoCommand(console: console)
        drop.commands = [
            command
        ]

        do {
            try drop.runCommands()
            XCTAssert(console.input().contains("123abc"), "Did not print 123abc")
        } catch {
            XCTFail("Command 2 failed to run: \(error)")
        }
    }

    func testDefaultServe() throws {
        final class TestServe: Command {
            let id: String = "serve"
            let console: ConsoleProtocol
            static var ran = false

            init(console: ConsoleProtocol) {
                self.console = console
            }

            func run(arguments: [String]) {
                TestServe.ran = true
            }
        }

        let drop = try Droplet(arguments: ["/path/to/exec"])
        drop.commands = [TestServe(console: drop.console)]

        do {
            try drop.runCommands()
            XCTAssert(TestServe.ran, "Serve did not default")
        } catch {
            XCTFail("Serve did not default: \(error)")
        }
    }
}

final class TestOneCommand: Command {
    let id: String = "test-1"
    let console: ConsoleProtocol
    var counter = 0

    init(console: ConsoleProtocol) {
        self.console = console
    }

    func run(arguments: [String]) throws {
        console.print("Test 1 Ran")
    }
}

final class TestTwoCommand: Command {
    let id: String = "test-2"
    let console: ConsoleProtocol

    let signature: [Argument] = [
        Console.Value(name: "arg-1"),
        Option(name: "opt-1"),
        Option(name: "opt-2")
    ]

    init(console: ConsoleProtocol) {
        self.console = console
    }

    func run(arguments: [String]) throws {
        let arg1 = try value("arg-1", from: arguments).string ?? ""
        console.print(arg1, newLine: false)

        let opt1 = arguments.option("opt-1")?.string ?? ""
        console.print(opt1, newLine: false)
    }
}

class TestConsoleDriver: ConsoleProtocol {
    var buffer: Bytes

    init() {
        buffer = []
    }

    func output(_ string: String, style: ConsoleStyle, newLine: Bool) {
        let string = newLine ? string + "\n" : string
        buffer += string.makeBytes()
    }

    func input() -> String {
        let string = buffer.makeString()
        buffer = []
        return string
    }

    func clear(_ clear: ConsoleClear) {

    }

    public func execute(program: String, arguments: [String], input: Int32?, output: Int32?, error: Int32?) throws {
    }

    func subexecute(_ command: String, input: String) throws -> String {
        return ""
    }


    let size: (width: Int, height: Int) = (0,0)
}
