import Console

@available(*, deprecated: 2.1, message: "Use `vapor --version` to log your current Vapor Framework version")
public final class VersionCommand: Command {
    public let id = "version"
    public let help = ["[Deprecated] Prints out the version of the Vapor framework being used."]
    public let console: ConsoleProtocol

    public init(_ console: ConsoleProtocol) {
        self.console = console
    }

    public func run(arguments: [String]) throws {
        console.warning("[Deprecated] ", newLine: false)
        console.info("Use `vapor --version` to log your current Vapor Framework version")
        try console.foregroundExecute(program: "vapor", arguments: ["--version"])
    }
}

/// Using this internally to prevent publicizing warnings to end user 
/// while also properly deprecating
internal final class _VersionCommand: Command {
    internal let id = "version"
    internal let help = ["[Deprecated] Prints out the version of the Vapor framework being used."]
    internal let console: ConsoleProtocol

    internal init(_ console: ConsoleProtocol) {
        self.console = console
    }

    internal func run(arguments: [String]) throws {
        console.warning("[Deprecated] ", newLine: false)
        console.info("Use `vapor --version` to log your current Vapor Framework version")
        try console.foregroundExecute(program: "vapor", arguments: ["--version"])
    }
}
