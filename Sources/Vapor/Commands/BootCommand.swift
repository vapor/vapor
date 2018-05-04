/// Boots the `Application`'s providers then exits successfully.
///
///     $ swift run Run boot
///     Done.
///
public struct BootCommand: Command, ServiceType {
    /// See `ServiceType`.
    public static func makeService(for worker: Container) throws -> BootCommand {
        return .init()
    }

    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return []
    }

    /// See `Command`.
    public let help: [String] = ["Boots the application's providers."]

    /// Create a new `BootCommand`.
    public init() { }

    /// See `Command`.
    public func run(using context: CommandContext) throws -> Future<Void> {
        context.console.success("Done.")
        return .done(on: context.container)
    }
}
