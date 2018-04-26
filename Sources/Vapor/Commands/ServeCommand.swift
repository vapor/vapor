/// Starts serving the `Application`'s `Responder` over HTTP.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public struct ServeCommand: Command, Service {
    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return [
            .value(name: "hostname", short: "h", help: ["Set the hostname the server will run on."]),
            .value(name: "port", short: "p", help: ["Set the port the server will run on."])
        ]
    }

    /// See `Command`.
    public let help: [String] = ["Begins serving the app over HTTP."]

    /// The server to boot.
    private let server: Server

    /// Create a new `ServeCommand`.
    public init(server: Server) {
        self.server = server
    }

    /// See `Command`.
    public func run(using context: CommandContext) throws -> Future<Void> {
        return server.start(
            hostname: context.options["hostname"],
            port: context.options["port"].flatMap { Int($0) }
        )
    }
}
