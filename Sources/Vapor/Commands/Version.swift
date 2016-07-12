public final class VersionCommand: Command {
    public let id = "version"
    public let help = ["Prints out the version of the Vapor framework being used."]
    public let console: Console

    public init(console: Console) {
        self.console = console
    }

    public func run(arguments: [String]) throws {
        console.print("Vapor Framework v\(VERSION)")
    }
}

