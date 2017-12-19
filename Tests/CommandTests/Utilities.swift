import Async
import Console
import Command

extension String: Error {}

final class TestGroup: Group {
    let commands: Commands = [
        "test": TestCommand(),
        "sub": SubGroup()
    ]

    let options = [
        Option(name: "version", help: ["Prints the version"])
    ]

    let help = ["This is a test grouping!"]

    func run(using console: Console, with input: Input) throws {
        if input.options["version"] == "true" {
            console.print("v2.0")
        } else {
            throw "unknown"
        }
    }
}

final class SubGroup: Group {
    let commands: Commands = [
        "test": TestCommand()
    ]

    let options = [
        Option(name: "version", help: ["Prints the version"])
    ]

    let help = ["This is a test sub grouping!"]

    func run(using console: Console, with input: Input) throws {
        if input.options["version"] == "true" {
            console.print("v2.0")
        } else {
            throw "unknown"
        }
    }
}

final class TestCommand: Command {
    let arguments = [
        Argument(
            name: "foo",
            help: ["A foo is required", "An error will occur if none exists"]
        )
    ]

    let options = [
        Option(
            name: "bar",
            help: ["Add a bar if you so desire", "Try passing it"]
        )
    ]

    let help = ["This is a test command"]

    func run(using console: Console, with input: Input) throws {
        let foo = try input.argument("foo")
        let bar = try input.requireOption("bar")
        console.info("Foo: \(foo) Bar: \(bar)")
    }
}
