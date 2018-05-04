/// Starts serving the `Application`'s `Responder` over HTTP.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public struct ServeCommand: Command, ServiceType {
    /// See `ServiceType`.
    public static func makeService(for container: Container) throws -> ServeCommand {
        return try ServeCommand(server: container.make())
    }

    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return [
            .value(name: "hostname", short: "H", help: ["Set the hostname the server will run on."]),
            .value(name: "port", short: "p", help: ["Set the port the server will run on."]),
            .value(name: "bind", short: "b", help: ["Convenience for setting hostname and port together."]),
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
            hostname: context.options["hostname"]
                // 0.0.0.0:8080, 0.0.0.0, parse hostname
                ?? context.options["bind"]?.split(separator: ":").first.flatMap(String.init),
            port: context.options["port"].flatMap(Int.init)
                // 0.0.0.0:8080, :8080, parse port
                ?? context.options["bind"]?.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
        )
    }
}
