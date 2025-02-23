import ConsoleKit
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

/// Core type representing a Vapor application.
public final class Application: Sendable {
    public var environment: Environment {
        get {
            self._environment.withLockedValue { $0 }
        }
        set {
            self._environment.withLockedValue { $0 = newValue }
        }
    }
    
    public var storage: Storage {
        get {
            self._storage.withLockedValue { $0 }
        }
        set {
            self._storage.withLockedValue { $0 = newValue }
        }
    }
    
    public var didShutdown: Bool {
        self._didShutdown.withLockedValue { $0 }
    }
    
    public var logger: Logger {
        get {
            self._logger.withLockedValue { $0 }
        }
        set {
            self._logger.withLockedValue { $0 = newValue }
        }
    }
    
    /// If enabled, tracing propagation is automatically handled by restoring & setting `request.serviceContext` automatically across Vapor-internal EventLoopFuture boundaries.
    /// If disabled, traces will not automatically nest, and the user should restore & set `request.serviceContext` manually where needed.
    /// There are performance implications to enabling this feature.
    public var traceAutoPropagation: Bool {
        get {
            self._traceAutoPropagation.withLockedValue { $0 }
        }
        set {
            self._traceAutoPropagation.withLockedValue { $0 = newValue }
        }
    }
    
    public struct Lifecycle: Sendable {
        var handlers: [LifecycleHandler]
        init() {
            self.handlers = []
        }
        
        public mutating func use(_ handler: LifecycleHandler) {
            self.handlers.append(handler)
        }
    }
    
    public var lifecycle: Lifecycle {
        get {
            self._lifecycle.withLockedValue { $0 }
        }
        set {
            self._lifecycle.withLockedValue { $0 = newValue }
        }
    }
    
    public final class Locks: Sendable {
        public let main: NIOLock
        // Is there a type we can use to make this Sendable but reuse the existing lock we already have?
        private let storage: NIOLockedValueBox<[ObjectIdentifier: NIOLock]>
        
        init() {
            self.main = .init()
            self.storage = .init([:])
        }
        
        public func lock<Key>(for key: Key.Type) -> NIOLock
        where Key: LockKey {
            self.main.withLock {
                self.storage.withLockedValue {
                    $0.insertOrReturn(.init(), at: .init(Key.self))
                }
            }
        }
    }
    
    public var locks: Locks {
        get {
            self._locks.withLockedValue { $0 }
        }
        set {
            self._locks.withLockedValue { $0 = newValue }
        }
    }
    
    public var sync: NIOLock {
        self.locks.main
    }
    
    public enum EventLoopGroupProvider: Sendable {
        case shared(EventLoopGroup)
        public static var singleton: EventLoopGroupProvider {
            .shared(MultiThreadedEventLoopGroup.singleton)
        }
    }
    
    public let eventLoopGroupProvider: EventLoopGroupProvider
    public let eventLoopGroup: EventLoopGroup
    internal let isBooted: NIOLockedValueBox<Bool>
    private let _environment: NIOLockedValueBox<Environment>
    private let _storage: NIOLockedValueBox<Storage>
    private let _didShutdown: NIOLockedValueBox<Bool>
    private let _logger: NIOLockedValueBox<Logger>
    private let _traceAutoPropagation: NIOLockedValueBox<Bool>
    private let _lifecycle: NIOLockedValueBox<Lifecycle>
    private let _locks: NIOLockedValueBox<Locks>

    // MARK: - Services
    package let contentConfiguration: ContentConfiguration
    package let byteBufferAllocator: ByteBufferAllocator = .init()

    public struct ServiceConfiguration {
        let contentConfiguration: ContentConfiguration

        public init(contentConfiguration: ContentConfiguration = .default()) {
            self.contentConfiguration = contentConfiguration
        }
    }

    // MARK: - Initialization

    public convenience init(
        _ environment: Environment = .development,
        _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton,
        services: ServiceConfiguration = .init()
    ) async throws {
        self.init(environment, eventLoopGroupProvider, services: services, internal: true)
        await self.asyncCommands.use(self.servers.command, as: "serve", isDefault: true)
        await DotEnvFile.load(for: self.environment, logger: self.logger)
    }
    
    // internal flag here is just to stop the compiler from complaining about duplicates
    package init(_ environment: Environment = .development, _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton, services: ServiceConfiguration, internal: Bool) {
        self._environment = .init(environment)
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        }
        self._locks = .init(.init())
        self._didShutdown = .init(false)
        let logger = Logger(label: "codes.vapor.application")
        self._logger = .init(logger)
        self._traceAutoPropagation = .init(false)
        self._storage = .init(.init(logger: logger))
        self._lifecycle = .init(.init())
        self.isBooted = .init(false)
        self.contentConfiguration = services.contentConfiguration

        // Service Setup
        self.core.initialize()
        self.caches.initialize()
        self.views.initialize()
        self.passwords.use(.bcrypt)
        self.sessions.initialize()
        self.sessions.use(.memory)
        self.responder.initialize()
        self.responder.use(.default)
        self.servers.initialize()
        self.servers.use(.http)
        self.clients.initialize()
        self.clients.use(.http)
        self.asyncCommands.use(RoutesCommand(), as: "routes")
    }
    
    /// Starts the ``Application`` asynchronous using the ``startup()`` method, then waits for any running tasks
    /// to complete. If your application is started without arguments, the default argument is used.
    ///
    /// Under normal circumstances, ``execute()`` runs until a shutdown is triggered, then wait for the web server to
    /// (manually) shut down before returning.
    public func execute() async throws {
        do {
            try await self.startup()
            try await self.running?.onStop.get()
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }
    
    /// When called, this will asynchronously execute the startup command provided through an argument. If no startup
    /// command is provided, the default is used. Under normal circumstances, this will start running Vapor's webserver.
    ///
    /// If you start Vapor through this method, you'll need to prevent your Swift Executable from closing yourself.
    /// If you want to run your ``Application`` indefinitely, or until your code shuts the application down,
    /// use ``execute()`` instead.
    public func startup() async throws {
        try await self.boot()

        let combinedCommands = AsyncCommands(
            commands: self.asyncCommands.commands.merging(self.commands.commands) { $1 },
            defaultCommand: self.asyncCommands.defaultCommand ?? self.commands.defaultCommand,
            enableAutocomplete: self.asyncCommands.enableAutocomplete || self.commands.enableAutocomplete
        ).group()

        var context = CommandContext(console: self.console, input: self.environment.commandInput)
        context.application = self
        try await self.console.run(combinedCommands, with: context)
    }
    
    /// Called when the applications starts up, will trigger the lifecycle handlers. The asynchronous version of ``boot()``
    public func boot() async throws {
        /// Skip the boot process if already booted
        guard !self.isBooted.withLockedValue({
            var result = true
            swap(&$0, &result)
            return result
        }) else {
            return
        }

        for handler in self.lifecycle.handlers {
            try await handler.willBoot(self)
        }
        for handler in self.lifecycle.handlers {
            try await handler.didBoot(self)
        }
    }
    
    public func shutdown() async throws {
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Shutting down providers")
        for handler in self.lifecycle.handlers.reversed()  {
            await handler.shutdown(self)
        }
        self.lifecycle.handlers = []

        self.logger.trace("Clearing Application storage")
        await self.storage.shutdown()
        self.storage.clear()

        switch self.eventLoopGroupProvider {
        case .shared:
            self.logger.trace("Running on shared EventLoopGroup. Not shutting down EventLoopGroup.")
        }

        self._didShutdown.withLockedValue { $0 = true }
        self.logger.trace("Application shutdown complete")
    }

    deinit {
        self.logger.trace("Application deinitialized, goodbye!")
        assert(self.didShutdown, "Application.shutdown() was not called before Application deinitialized.")
    }
}

public protocol LockKey {}

extension Dictionary {
    fileprivate mutating func insertOrReturn(_ value: @autoclosure () -> Value, at key: Key) -> Value {
        if let existing = self[key] {
            return existing
        }
        let newValue = value()
        self[key] = newValue
        return newValue
    }
}
