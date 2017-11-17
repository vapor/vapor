import Async
import Console
import Command

final class TestConsole: Console {
    var output: String
    var input: String
    var error: String
    var lastAction: ConsoleAction?
    var extend = Extend()

    init() {
        self.output = ""
        self.input = ""
        self.error = ""
        self.lastAction = nil
    }

    func action(_ action: ConsoleAction) throws -> String? {
        switch action {
        case .input(_):
            let t = input
            input = ""
            return t
        case .output(let output, _, let newLine):
            self.output += output + (newLine ? "\n" : "")
        case .error(let error, let newLine):
            self.error += error + (newLine ? "\n" : "")
        default:
            break
        }
        lastAction = action
        return nil
    }

    var size: (width: Int, height: Int) {
        return (640, 320)
    }
}

final class TestGroup: Command {
    let signature = CommandSignature(group: [
        "test": TestCommand(),
        "sub": SubGroup()
    ], options: [
        CommandOption(name: "version", help: ["Prints the version"])
    ], help: ["This is a test grouping!"])

    func run(using console: Console, with input: CommandInput) throws {
        if input.options["version"]?.bool == true {
            try console.print("v2.0")
        } else {
            throw "unknown"
        }
    }
}

final class SubGroup: Command {
    let signature = CommandSignature(group: [
        "test": TestCommand()
    ], options: [
        CommandOption(name: "version", help: ["Prints the version"])
    ], help: ["This is a test sub grouping!"])

    func run(using console: Console, with input: CommandInput) throws {
        if input.options["version"]?.bool == true {
            try console.print("v2.0")
        } else {
            throw "unknown"
        }
    }
}

final class TestCommand: Command {
    let signature = CommandSignature(arguments: [
        CommandArgument(name: "foo", help: ["A foo is required", "An error will occur if none exists"])
    ], options: [
        CommandOption(name: "bar", help: ["Add a bar if you so desire", "Try passing it"])
    ], help: ["This is a test command"])

    func run(using console: Console, with input: CommandInput) throws {
        let foo = try input.argument("foo")
        let bar = try input.requireOption("bar")
        try console.info("Foo: \(foo) Bar: \(bar)")
    }
}
