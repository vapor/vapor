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
        return config
    }

    /// Converts the config into a command group.
    internal func makeCommandGroup(for container: Container) throws -> BasicCommandGroup {
        let commands = try self.commands.mapValues { try $0(container) }
        return BasicCommandGroup(
            commands: commands,
            options: [],
            help: ["Runs your Vapor application's commands"]
        ) { console, input in
            if let def = self.defaultRunnable {
                try def(container).run(using: console, with: input)
            } else {
                throw "No default command"
            }
        }
    }
}

/// Starts serving the app's responder over HTTP.
public struct ServeCommand: Command {
    /// See Command.arguments
    public let arguments: [Argument] = []

    /// See Runnable.options
    public let options: [Option] = []

    /// See Runnable.help
    public let help: [String] = ["Begins serving the app over HTTP"]

    /// The server to boot.
    public let server: Server
    public let responder: Responder

    /// Create a new serve command.
    public init(server: Server, responder: Responder) {
        self.server = server
        self.responder = responder
    }

    /// See Runnable.run
    public func run(using console: Console, with input: Input) throws {
        try server.start(with: responder)
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
