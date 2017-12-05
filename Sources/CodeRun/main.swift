import Code
import Command
import Console
import libc

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
do {
    try terminal.run(code, arguments: CommandLine.arguments)
} catch {
    print(error)
    exit(1)
}
