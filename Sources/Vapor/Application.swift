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
        @available(*, deprecated, renamed: "singleton", message: "Use '.singleton' for a shared 'EventLoopGroup', for better performance")
        case createNew
        
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
    
    @available(*, noasync, message: "This initialiser cannot be used in async contexts, use Application.make(_:_:) instead")
    @available(*, deprecated, message: "Migrate to using the async APIs. Use use Application.make(_:_:) instead")
    public convenience init(
        _ environment: Environment = .development,
        _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton
    ) {
        self.init(environment, eventLoopGroupProvider, async: false)
        self.asyncCommands.use(self.servers.command, as: "serve", isDefault: true)
        DotEnvFile.load(for: environment, on: .shared(self.eventLoopGroup), fileio: self.fileio, logger: self.logger)
    }
    
    // async flag here is just to stop the compiler from complaining about duplicates
    private init(_ environment: Environment = .development, _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton, async: Bool) {
        self._environment = .init(environment)
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        }
        self._locks = .init(.init())
        self._didShutdown = .init(false)
        let logger = Logger(label: "codes.vapor.application")
        self._logger = .init(logger)
        self._traceAutoPropagation = .init(false)
        self._storage = .init(.init(logger: logger))
        self._lifecycle = .init(.init())
        self.isBooted = .init(false)
        self.core.initialize(asyncEnvironment: async)
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
    
    public static func make(_ environment: Environment = .development, _ eventLoopGroupProvider: EventLoopGroupProvider = .singleton) async throws -> Application {
        let app = Application(environment, eventLoopGroupProvider, async: true)
        await app.asyncCommands.use(app.servers.asyncCommand, as: "serve", isDefault: true)
        await DotEnvFile.load(for: app.environment, fileio: app.fileio, logger: app.logger)
        return app
    }

    /// Starts the ``Application`` using the ``start()`` method, then waits for any running tasks to complete.
    /// If your application is started without arguments, the default argument is used.
    ///
    /// Under normal circumstances, ``run()`` runs until a shutdown is triggered, then waits for the web server to
    /// (manually) shut down before returning.
    ///
    /// > Warning: You should probably be using ``execute()`` instead of this method.
    @available(*, noasync, message: "Use the async execute() method instead.")
    public func run() throws {
        do {
            try self.start()
            try self.running?.onStop.wait()
        } catch {
            self.logger.report(error: error)
            throw error
        }
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

    /// When called, this will execute the startup command provided through an argument. If no startup command is
    /// provided, the default is used. Under normal circumstances, this will start running Vapor's webserver.
    ///
    /// If you start Vapor through this method, you'll need to prevent your Swift Executable from closing yourself.
    /// If you want to run your ``Application`` indefinitely, or until your code shuts the application down,
    /// use ``run()`` instead.
    ///
    /// > Warning: You should probably be using ``startup()`` instead of this method.
    @available(*, noasync, message: "Use the async startup() method instead.")
    public func start() throws {
        try self.eventLoopGroup.any().makeFutureWithTask { try await self.startup() }.wait()
    }
    
    /// When called, this will asynchronously execute the startup command provided through an argument. If no startup
    /// command is provided, the default is used. Under normal circumstances, this will start running Vapor's webserver.
    ///
    /// If you start Vapor through this method, you'll need to prevent your Swift Executable from closing yourself.
    /// If you want to run your ``Application`` indefinitely, or until your code shuts the application down,
    /// use ``execute()`` instead.
    public func startup() async throws {
        try await self.asyncBoot()

        let combinedCommands = AsyncCommands(
            commands: self.asyncCommands.commands.merging(self.commands.commands) { $1 },
            defaultCommand: self.asyncCommands.defaultCommand ?? self.commands.defaultCommand,
            enableAutocomplete: self.asyncCommands.enableAutocomplete || self.commands.enableAutocomplete
        ).group()

        var context = CommandContext(console: self.console, input: self.environment.commandInput)
        context.application = self
        try await self.console.run(combinedCommands, with: context)
    }

    
    @available(*, noasync, message: "This can potentially block the thread and should not be called in an async context", renamed: "asyncBoot()")
    /// Called when the applications starts up, will trigger the lifecycle handlers
    public func boot() throws {
        try self.isBooted.withLockedValue { booted in
            guard !booted else {
                return
            }
            booted = true
            try self.lifecycle.handlers.forEach { try $0.willBoot(self) }
            try self.lifecycle.handlers.forEach { try $0.didBoot(self) }
        }
    }
    
    /// Called when the applications starts up, will trigger the lifecycle handlers. The asynchronous version of ``boot()``
    public func asyncBoot() async throws {
        /// Skip the boot process if already booted
        guard !self.isBooted.withLockedValue({
            var result = true
            swap(&$0, &result)
            return result
        }) else {
            return
        }

        for handler in self.lifecycle.handlers {
            try await handler.willBootAsync(self)
        }
        for handler in self.lifecycle.handlers {
            try await handler.didBootAsync(self)
        }
    }

    @available(*, noasync, message: "This can block the thread and should not be called in an async context", renamed: "asyncShutdown()")
    public func shutdown() {
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Shutting down providers")
        self.lifecycle.handlers.reversed().forEach { $0.shutdown(self) }
        self.lifecycle.handlers = []

        self.logger.trace("Clearing Application storage")
        self.storage.shutdown()
        self.storage.clear()

        switch self.eventLoopGroupProvider {
        case .shared:
            self.logger.trace("Running on shared EventLoopGroup. Not shutting down EventLoopGroup.")
        case .createNew:
            self.logger.trace("Shutting down EventLoopGroup")
            do {
                try self.eventLoopGroup.syncShutdownGracefully()
            } catch {
                self.logger.warning("Shutting down EventLoopGroup failed: \(error)")
            }
        }

        self._didShutdown.withLockedValue { $0 = true }
        self.logger.trace("Application shutdown complete")
    }
    
    public func asyncShutdown() async throws {
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Shutting down providers")
        for handler in self.lifecycle.handlers.reversed()  {
            await handler.shutdownAsync(self)
        }
        self.lifecycle.handlers = []

        self.logger.trace("Clearing Application storage")
        await self.storage.asyncShutdown()
        self.storage.clear()

        switch self.eventLoopGroupProvider {
        case .shared:
            self.logger.trace("Running on shared EventLoopGroup. Not shutting down EventLoopGroup.")
        case .createNew:
            self.logger.trace("Shutting down EventLoopGroup")
            do {
                try await self.eventLoopGroup.shutdownGracefully()
            } catch {
                self.logger.warning("Shutting down EventLoopGroup failed: \(error)")
            }
        }

        self._didShutdown.withLockedValue { $0 = true }
        self.logger.trace("Application shutdown complete")
    }

    deinit {
        self.logger.trace("Application deinitialized, goodbye!")
        if !self.didShutdown {
            self.logger.error("Application.shutdown() was not called before Application deinitialized.")
            self.shutdown()
        }
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
