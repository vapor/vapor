import Command
import Console

/// Starts serving the app's responder over HTTP.
public struct ServeCommand: Command, Service {
    /// See Command.arguments
    public let arguments: [CommandArgument] = []

    /// See Runnable.options
    public let options: [CommandOption] = []

    /// See Runnable.help
    public let help: [String] = ["Begins serving the app over HTTP"]

    /// The server to boot.
    public let server: Server

    /// Create a new serve command.
    public init(server: Server) {
        self.server = server
    }

    /// See Runnable.run
    public func run(using context: CommandContext) throws {
        try server.start()
    }
}
