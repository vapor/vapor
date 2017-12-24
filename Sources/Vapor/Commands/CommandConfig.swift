import Command
import Console
import Foundation

/// Helps configure which commands will
/// run when the application boots.
public struct CommandConfig {
    /// A not-yet configured runnable.
    public typealias LazyRunnable = (Container) throws -> Runnable

    /// Internal storage
    var commands: [String: LazyRunnable]

    /// The default runnable
    var defaultRunnable: LazyRunnable?

    /// Create a new command config.
    public init() {
        self.commands = [:]
    }

    /// Add a Command or Group to the config.
    public mutating func add(
        _ command: Runnable,
        named name: String,
        isDefault: Bool = false
        ) {
        commands[name] = { _ in command }
        if isDefault {
            defaultRunnable = { _ in command }
        }
    }

    /// Add a Command or Group to the config.
    public mutating func add<R>(
        _ command: R.Type,
        named name: String,
        isDefault: Bool = false
        ) where R: Runnable {
        commands[name] = { try $0.make(R.self, for: CommandConfig.self) }
        if isDefault {
            defaultRunnable = { try $0.make(R.self, for: CommandConfig.self) }
        }
    }

    /// A command config with default commands already included.
    public static func `default`() -> CommandConfig {
        var config = CommandConfig()
        config.add(ServeCommand.self, named: "serve", isDefault: true)
        config.add(RoutesCommand.self, named: "routes")
        return config
    }

    /// Converts the config into a command group.
    internal func makeCommandGroup(for container: Container) throws -> BasicCommandGroup {
        let commands = try self.commands.mapValues { lazy -> Runnable in
            let runnable = try lazy(container)
            if let command = runnable as? Command {
                return VaporCommandWrapper(command)
            } else {
                return runnable
            }
        }
        return BasicCommandGroup(
            commands: commands,
            options: [envOption, portOption],
            help: ["Runs your Vapor application's commands"]
        ) { console, input in
            if let lazy = self.defaultRunnable {
                try lazy(container).run(using: console, with: input)
            } else {
                throw VaporError(identifier: "no-default-command", reason: "There is no default command in Vapor")
            }
        }
    }
}

let envOption = Option(name: "env", help: [
    "Changes the environment (if Environment.detect() is being used)",
    "Ex: prod, dev, test, my-custom-env"
], default: nil)

let portOption = Option(name: "port", help: [
    "Changes the port"
], default: nil)


/// Wraps all vapor commands and adds support
/// for the `--env` flag which is resolved outside
/// of this module
internal struct VaporCommandWrapper: Command {
    /// The wrapped command
    var subCommand: Command

    /// See Command.arguments
    var arguments: [Argument] {
        return subCommand.arguments
    }

    /// See Runnable.options
    var options: [Option] {
        return subCommand.options + [envOption]
    }

    /// See Runnable.help
    var help: [String] {
        return subCommand.help
    }

    /// Creates a new vapor command wrapper around a subcommand
    init(_ subCommand: Command) {
        self.subCommand = subCommand
    }

    /// See Runnable.run
    func run(using console: Console, with input: Input) throws {
        try subCommand.run(using: console, with: input)
    }
}

/// A basic command group.
internal struct BasicCommandGroup: Group {
    /// See Group.commands
    var commands: Commands

    /// See Runnable.options
    var options: [Option]

    /// See Runnable.help
    var help: [String]

    /// Closure to be called on run.
    typealias OnRun = (Console, Input) throws -> ()
    var onRun: OnRun

    /// See Runnable.run
    func run(using console: Console, with input: Input) throws {
        try onRun(console, input)
    }
}

