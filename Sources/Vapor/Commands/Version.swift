import Console

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
