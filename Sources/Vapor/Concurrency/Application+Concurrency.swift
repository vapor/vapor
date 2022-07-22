#if compiler(>=5.5) && canImport(_Concurrency)
import ConsoleKit

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Application {

    /// Async version of ``start()``. Honors the commands registered in ``asyncCommands-swift.property``
    /// in addition to the ones registered on ``commands``. Otherwise identical to the non-async version.
    public func start() async throws {
        self.asyncCommands.merge(oldCommands: self.commands.commands)

        try self.boot()
        let command = self.asyncCommands.group()
        var context = CommandContext(console: self.console, input: self.environment.commandInput)
        context.application = self
        try await self.console.run(command, with: context)
    }

    /// Async version of ``run()``. Identical to the non-async version except that the async version
    /// of ``start()`` is called instead.
    public func run() async throws {
        do {
            try await self.start()
            try await self.running?.onStop.get()
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }

}

#endif
