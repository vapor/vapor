import ConsoleKit

/// Boots the `Application` then exits successfully.
///
///     $ swift run Run boot
///     Done.
///
public final class BootCommand: Command {
    /// See `Command`.
    public struct Signature: CommandSignature {
        public init() { }
    }

    /// See `Command`.
    public var help: String {
        return "Boots the application's providers."
    }

    /// Create a new `BootCommand`.
    public init() { }

    /// See `Command`.
    public func run(using context: CommandContext, signature: Signature) throws {
        context.console.success("Done.")
    }
}
