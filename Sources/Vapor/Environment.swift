extension Environment {
    /// Exposes the `Environment`'s `arguments` property as a `CommandInput`.
    public var commandInput: CommandInput {
        get { return CommandInput(arguments: arguments) }
        set { arguments = newValue.executablePath + newValue.arguments }
    }
    
    /// Detects the environment from `CommandLine.arguments`. Invokes `detect(from:)`.
    /// - parameters:
    ///     - arguments: Command line arguments to detect environment from.
    /// - returns: The detected environment, or default env.
    public static func detect(arguments: [String] = CommandLine.arguments) throws -> Environment {
        var commandInput = CommandInput(arguments: arguments)
        return try Environment.detect(from: &commandInput)
    }
    
    /// Detects the environment from `CommandInput`. Parses the `--env` flag.
    /// - parameters:
    ///     - arguments: `CommandInput` to parse `--env` flag from.
    /// - returns: The detected environment, or default env.
    public static func detect(from commandInput: inout CommandInput) throws -> Environment {
        var env: Environment
        if let value = try commandInput.parse(option: .value(name: "env", short: "e")) {
            switch value {
            case "prod", "production": env = .production
            case "dev", "development": env = .development
            case "test", "testing": env = .testing
            default: env = .init(name: value)
            }
        } else {
            env = .development
        }
        env.commandInput = commandInput
        return env
    }
}

#warning("TODO: consider removing isRelease from environment, only rely on swift build mode")
