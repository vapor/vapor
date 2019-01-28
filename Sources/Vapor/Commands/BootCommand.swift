/// Boots the `Application`'s providers then exits successfully.
///
///     $ swift run Run boot
///     Done.
///
public struct BootCommand: Command {
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
    public func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        context.console.success("Done.")
        return context.eventLoop.makeSucceededFuture(())
    }
}
