import ConsoleKit

/// Boots the `Application` then exits successfully.
///
///     $ swift run Run boot
///     Done.
///
public final class BootCommand: AsyncCommand {
    // See `AsyncCommand`.
    public struct Signature: CommandSignature {
        public init() {}
    }

    // See `AsyncCommand`.
    public var help: String {
        return "Boots the application's providers."
    }

    /// Create a new `BootCommand`.
    public init() {}

    // See `AsyncCommand`.
    public func run(using context: ConsoleKitCommands.CommandContext, signature: Signature) async throws {
        context.console.success("Done.")
    }
}
