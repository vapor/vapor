#if compiler(>=5.5) && canImport(_Concurrency)
import ConsoleKit

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Application {

    /// Namespacing wrapper to isolate additional API for starting from an async entrypoint.
    public struct Async {
        let application: Application
        
        /// Public interface to the `Application.asyncCommands` provider, which is deliberately made publicly
        /// visible only through this namespace.
        public var commands: AsyncCommands {
            get { self.application.asyncCommands }
        }
        
        /// Async version of ``start()``. Honors the commands registered in ``asyncCommands-swift.property``
        /// in addition to the ones registered on ``commands``. Otherwise identical to the non-async version.
        public func start() async throws {
            self.commands.merge(oldCommands: self.application.commands.commands)

            try self.application.boot()
            let command = self.commands.group()
            var context = CommandContext(console: self.application.console, input: self.application.environment.commandInput)
            context.application = self.application
            try await self.application.console.run(command, with: context)
        }

        /// Async version of ``run()``. Identical to the non-async version except that the async version
        /// of ``start()`` is called instead.
        public func run() async throws {
            do {
                try await self.start()
                try await self.application.running?.onStop.get()
            } catch {
                self.application.logger.report(error: error)
                throw error
            }
        }
    }
    
    public var async: Async {
        .init(application: self)
    }
}

#endif
