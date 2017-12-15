import Async
import Console
import Command

extension String: Error {}

final class TestGroup: Group {
    let commands: Commands = [
        "test": TestCommand(),
        "sub": SubGroup(),
        "setup-autocomplete": SetupAutocomplete()
    ]
    
    let options = [
        Option(name: "version", help: ["Prints the version"])
    ]
    
    let help = ["This is a test grouping!"]
    
    func run(using console: Console, with input: Input) throws {
        if input.options["version"]?.bool == true {
            console.print("v2.0")
        } else {
            throw "unknown"
        }
    }
}

final class SetupAutocomplete: Group {
    
    let help = ["Setup autocomplete on your Mac"]
    
    let options = [
        Option(name: "version", help: ["Prints the version"])
    ]
    
    let commands: Commands = [
        "test": TestCommand()
    ]
    
    func run(using console: Console, with input: Input) throws {
        var arguments = CommandLine.arguments
        var iterator = arguments.makeIterator()
        let executable = iterator.next()
        
        console.print("First install bash-completion:")
        console.print("  brew install bash-completion")
        console.print("")
        console.print("  curl -s ", newLine: false)
        console.print("https://gist.githubusercontent.com/joscdk/bc05dfc9c6aafee0fa90bc836939584e/raw/cc3ff5de020f771547a49c3fce27a3fee65ae47c/gistfile1.txt ", newLine: false)
        console.print("| bash /dev/stdin CommandExample \(executable ?? "")")
        console.print("")
        console.print("After this, restart your bash")
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
        if input.options["version"]?.bool == true {
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

let console = Terminal()
let group = TestGroup()

try! console.run(group, arguments: CommandLine.arguments)
