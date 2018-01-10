import Command
import Console

/// Starts serving the app's responder over HTTP.
public struct ServeCommand: Command, Service {
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
