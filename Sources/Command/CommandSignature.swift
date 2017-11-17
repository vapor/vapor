/// Defines a command's signature.
public struct CommandSignature {
    /// The required arguments.
    public let arguments: CommandArguments

    /// The supported options.
    public let options: [CommandOption]

    /// Text that will be displayed when `--help` is passed.
    public let help: [String]

    /// Creates a new command signature struct with nested commands.
    public init(group: [String: Command], options: [CommandOption], help: [String]) {
        self.arguments = .group(group)
        self.options = options
        self.help = help
    }

    /// Creates a new command signature struct with arguments.
    public init(arguments: [CommandArgument], options: [CommandOption], help: [String]) {
        self.arguments = .array(arguments)
        self.options = options
        self.help = help
    }
}

public enum CommandArguments {
    case group([String: Command])
    case array([CommandArgument])
}

/// A required argument for a command.
///
///     exec command <arg>
///
public struct CommandArgument {
    /// The argument's unique name.
    public let name: String

    /// The arguments's help text when `--help` is passed.
    public let help: [String]

    /// Creates a new command argument
    public init(name: String, help: [String] = []) {
        self.name = name
        self.help = help
    }
}

/// A supported option for a command.
///
///     exec command [--opt]
///
public struct CommandOption {
    /// The option's unique name.
    public let name: String

    /// The option's help text when `--help` is passed.
    public let help: [String]

    /// The option's default value, if supplied
    public let `default`: String?

    /// Creates a new command option.
    public init(name: String, help: [String] = [], default: String? = nil) {
        self.name = name
        self.help = help
        self.`default` = `default`
    }
}
