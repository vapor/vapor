import Command
import Console
import Foundation

/// Helps configure which commands will run when the application boots.
public struct CommandConfig: Service {
    /// A not-yet configured runnable.
    public typealias LazyRunnable = (Container) throws -> CommandRunnable

    /// Internal storage
    var commands: [String: LazyRunnable]

    /// The default runnable
    var defaultRunnable: LazyRunnable?

    /// Create a new command config.
    public init() {
        self.commands = [:]
    }

    /// Add a Command or Group to the config.
    public mutating func use(
        _ command: CommandRunnable,
        as name: String,
        isDefault: Bool = false
    ) {
        commands[name] = { _ in command }
        if isDefault {
            defaultRunnable = { _ in command }
        }
    }

    /// Add a Command or Group to the config.
    public mutating func use<R>(
        _ command: R.Type,
        as name: String,
        isDefault: Bool = false
    ) where R: CommandRunnable {
        commands[name] = { try $0.make(R.self) }
        if isDefault {
            defaultRunnable = { try $0.make(R.self) }
        }
    }

    /// A command config with default commands already included.
    public static func `default`() -> CommandConfig {
        var config = CommandConfig()
        config.use(ServeCommand.self, as: "serve", isDefault: true)
        config.use(RoutesCommand.self, as: "routes")
        return config
    }

    /// Converts the config into a command group.
    internal func makeCommandGroup(for container: Container) throws -> MainCommand {
        let commands = try self.commands.mapValues { lazy -> CommandRunnable in
            return try lazy(container)
        }
        return try MainCommand(
            commands: commands,
            defaultRunnable: defaultRunnable.flatMap { try $0(container) }
        )
    }
}
