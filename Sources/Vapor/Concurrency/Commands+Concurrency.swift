#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore
import ConsoleKit

/// Trivial adapter to turn non-async ``Command``s into ``AsyncCommand``s.
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
struct AnyCommandAsyncAdapter: AnyAsyncCommand {
    private let syncCommand: AnyCommand
    
    init(_ syncCommand: AnyCommand) {
        self.syncCommand = syncCommand
    }
    
    var help: String {
        self.syncCommand.help
    }

    func run(using context: inout CommandContext) async throws {
        try self.syncCommand.run(using: &context)
    }

    func outputAutoComplete(using context: inout CommandContext) throws {
        try self.syncCommand.outputAutoComplete(using: &context)
    }

    func outputHelp(using context: inout CommandContext) throws {
        try self.syncCommand.outputHelp(using: &context)
    }

    func renderCompletionFunctions(using context: CommandContext, shell: Shell) -> String {
        self.syncCommand.renderCompletionFunctions(using: context, shell: shell)
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Application {

    /// A provider for an async counterpart to ``Application``'s existing ``Commands``.
    public struct AsyncCommands {
        
        // MARK: - Provider boilerplate
        final class Storage {
            var asyncCommands = ConsoleKit.AsyncCommands()
        }

        struct Key: StorageKey { typealias Value = Storage }
        
        let application: Application
        
        var storage: Storage { self.application.storage[Key.self, default: .init()] }
        
        // MARK: - API access for ``ConsoleKit/AsyncCommands``

        /// Direct access to the underlying ``ConsoleKit/AsyncCommands`` instance.
        public var asyncCommands: ConsoleKit.AsyncCommands {
            get { self.storage.asyncCommands }
            set { self.storage.asyncCommands = newValue }
        }
        
        /// See ``ConsoleKit/AsyncCommands/commands``.
        public var commands: [String: ConsoleKit.AnyAsyncCommand] {
            get { self.storage.asyncCommands.commands }
            set { self.storage.asyncCommands.commands = newValue }
        }
        
        /// See ``ConsoleKit/AsyncCommands/enableAutocomplete``.
        public var enableAutocomplete: Bool {
            get { self.storage.asyncCommands.enableAutocomplete }
            set { self.storage.asyncCommands.enableAutocomplete = newValue }
        }
        
        /// See ``ConsoleKit/AsyncCommands/defaultCommand``.
        public var defaultCommand: AnyAsyncCommand? {
            get { self.storage.asyncCommands.defaultCommand }
            set { self.storage.asyncCommands.defaultCommand = newValue }
        }
        
        /// See ``ConsoleKit/AsyncCommands/use(_:as:isDefault:)``.
        public mutating func use(_ command: AnyAsyncCommand, as name: String, isDefault: Bool = false) {
            self.storage.asyncCommands.use(command, as: name, isDefault: isDefault)
        }
        
        /// Allows directly registering ``AnyCommand``s.
        public mutating func use(_ command: AnyCommand, as name: String, isDefault: Bool = false) {
            self.use(AnyCommandAsyncAdapter(command), as: name, isDefault: isDefault)
        }
        
        /// See ``ConsoleKit/AsyncCommands/group(help:)``.
        public func group(help: String = "") -> ConsoleKit.AsyncCommandGroup {
            self.storage.asyncCommands.group(help: help)
        }
        
        // MARK: - Old/new merge logic
        
        /// Register async versions of the given non-async commands. This API is intended
        /// for use only by ``Application``.
        ///
        /// If a non-async command's name is already registered, a fatal error occurs.
        func merge(oldCommands: [String: AnyCommand]) {
            let commonKeys = Set(self.commands.keys).intersection(oldCommands.keys)
            precondition(commonKeys.isEmpty, "The following command names were registered multiple times: \(commonKeys)")
            
            self.storage.asyncCommands.commands.merge(oldCommands.mapValues(AnyCommandAsyncAdapter.init(_:))) { a, b in a }
        }
    }
    
    /// The async version of ``Application/commands``. See `Application+Concurrency.swift` for the public interface.
    internal var asyncCommands: AsyncCommands {
        .init(application: self)
    }

}

#endif
