/// A required argument for a command.
///
///     exec command <arg>
///
public struct Argument {
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
public struct Option {
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
