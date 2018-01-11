import Console
import Command

/// Vapor's main command.
internal struct MainCommand: CommandGroup {
    var commands: [String: CommandRunnable]
    var defaultRunnable: CommandRunnable?
    var options: [CommandOption]
    var help: [String]

    init(commands: [String: CommandRunnable], defaultRunnable: CommandRunnable?) {
        self.commands = commands
        self.options = [
            .flag(name: "version", short: "c", help: ["Displays the framework's version"])
        ]
        self.help = ["Runs your Vapor application's commands"]
    }

    func run(using context: CommandContext) throws {
        if context.options["version"] == "true" {
            context.console.info("Vapor Framework v", newLine: false)
            context.console.print("3.0")
        } else {
            if let lazy = self.defaultRunnable {
                try lazy.run(using: context)
            } else {
                throw VaporError(identifier: "no-default-command", reason: "There is no default command in Vapor")
            }
        }
    }
}
