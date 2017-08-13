import libc
import Command
import Console
import Dispatch

extension Droplet {
    /// Runs the Droplet's commands, defaulting to serve.
    public func run(arguments: [String] = CommandLine.arguments) throws {
        let console = try make(Console.self)

        let group = try VaporGroup(commands: make([Command.self]))
        try console.run(.group(group), arguments: arguments)
    }
}


struct VaporGroup: Group {
    var signature: GroupSignature

    init(commands: [Command]) {
        var runnables: [String: Runnable] = [:]

        for command in commands {
            runnables["\(type(of:command))"] = .command(command)
        }

        self.signature = .init(
            runnables: runnables,
            options: [],
            help: [
                "This command line interface is used to serve your droplet, prepare the database, and more.",
                "Custom commands can be added by appending them to the Droplet's commands array.",
                "Use --help on individual commands to learn more."
            ]
        )
    }

    func run(using console: Console, with input: GroupInput) throws {
        try console.run(signature.runnables["Serve"]!, arguments: [input.executable])
    }
}
