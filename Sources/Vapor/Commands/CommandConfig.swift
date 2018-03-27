import Command
import Console
import Foundation

/// Helps configure which commands will run when the application boots.
extension CommandConfig {
    /// A command config with default commands already included.
    public static func `default`() -> CommandConfig {
        var config = CommandConfig()
        config.use(ServeCommand.self, as: "serve", isDefault: true)
        config.use(RoutesCommand.self, as: "routes")
        return config
    }
}

extension ConfiguredCommands {
    /// Converts the config into a command group.
    internal func makeMainCommand() -> MainCommand {
        return MainCommand(
            commands: commands,
            defaultRunnable: defaultCommand
        )
    }
}
