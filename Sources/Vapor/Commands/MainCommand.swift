import Console
import Command

/// Vapor's main command group.
internal struct MainCommand: CommandGroup {
    /// See `CommandGroup`.
    var commands: [String: CommandRunnable]

    /// Command that will run if no other commands are specified.
    var defaultRunnable: CommandRunnable?

    /// See `CommandGroup`.
    var options: [CommandOption] {
        return [.flag(name: "version", short: "v", help: ["Displays the framework's version"])]
    }

    /// See `CommandGroup`.
    var help: [String] {
        return ["Runs your Vapor application's commands"]
    }

    /// Creates a new `MainCommand`.
    init(commands: [String: CommandRunnable], defaultRunnable: CommandRunnable?) {
        self.commands = commands
        self.defaultRunnable = defaultRunnable
    }

    /// See `CommandGroup`.
    func run(using context: CommandContext) throws -> Future<Void> {
        if context.options["version"] == "true" {
            context.console.info("Vapor Framework v", newLine: false)
            context.console.print("3.0")
        } else {
            if let lazy = self.defaultRunnable {
                return try lazy.run(using: context)
            } else {
                throw VaporError(identifier: "noDefaultCommand", reason: "No default command has been registered.", source: .capture())
            }
        }
        return .done(on: context.container)
    }
}
