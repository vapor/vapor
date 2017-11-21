import Code
import Command
import Console

struct CodeCommands: Group {
    var commands: Group.Commands = [
        "code": Generate()
    ]
    var options: [Option] = []
    var help: [String] = []

    func run(using console: Console, with input: Input) throws {

    }
}

let terminal = Terminal()
let code = CodeCommands()
try terminal.run(code, arguments: CommandLine.arguments)
