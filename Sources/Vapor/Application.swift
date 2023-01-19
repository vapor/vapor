import Backtrace
import NIOConcurrencyHelpers

/// Core type representing a Vapor application.
public final class Application {
    public var environment: Environment
    public let eventLoopGroupProvider: EventLoopGroupProvider
    public let eventLoopGroup: EventLoopGroup
    public var storage: Storage
    public private(set) var didShutdown: Bool
    public var logger: Logger
    var isBooted: Bool

    public struct Lifecycle {
        var handlers: [LifecycleHandler]
        init() {
            self.handlers = []
        }

        public mutating func use(_ handler: LifecycleHandler) {
            self.handlers.append(handler)
        }
    }

    public var lifecycle: Lifecycle

    public final class Locks {
        public let main: NIOLock
        var storage: [ObjectIdentifier: NIOLock]

        init() {
            self.main = .init()
            self.storage = [:]
        }

        public func lock<Key>(for key: Key.Type) -> NIOLock
            where Key: LockKey
        {
            self.main.lock()
            defer { self.main.unlock() }
            if let existing = self.storage[ObjectIdentifier(Key.self)] {
                return existing
            } else {
                let new = NIOLock()
                self.storage[ObjectIdentifier(Key.self)] = new
                return new
            }
        }
    }

    public var locks: Locks

    public var sync: NIOLock {
        self.locks.main
    }
    
    public enum EventLoopGroupProvider {
        case shared(EventLoopGroup)
        case createNew
    }

    public init(
        _ environment: Environment = .development,
        _ eventLoopGroupProvider: EventLoopGroupProvider = .createNew
    ) {
        Backtrace.install()
        self.environment = environment
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        }
        self.locks = .init()
        self.didShutdown = false
        self.logger = .init(label: "codes.vapor.application")
        self.storage = .init(logger: self.logger)
        self.lifecycle = .init()
        self.isBooted = false
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
        self.commands.use(self.servers.command, as: "serve", isDefault: true)
        self.commands.use(RoutesCommand(), as: "routes")
        DotEnvFile.load(for: environment, on: .shared(self.eventLoopGroup), fileio: self.fileio, logger: self.logger)
    }
    
    /// Starts the Application using the `start()` method, then blocks the thread while any tasks are running
    /// If your application is started without arguments, the default argument is used.
    ///
    /// Under normal circumstances, `run()` starts the webserver, then wait for the web server to (manually) shut down before returning.
    @available(*, noasync)
    public func run() throws {
        do {
            try self.start()
            try self.running?.onStop.wait()
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }
    
    /// Starts the Application using the `start()` method, then awaits the end of any tasks that are running
    /// If your application is started without arguments, the default argument is used.
    ///
    /// Under normal circumstances, `run()` starts the webserver, then wait for the web server to (manually) shut down before returning.
    public func run() async throws {
        do {
            try self.start()
            try await self.running?.onStop.get()
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }
    
    /// When called, this will execute the startup command provided through an argument. If no startup command is provided, the default is used.
    /// Under normal circumstances, this will start running Vapor's webserver.
    ///
    /// If you `start` Vapor through this method, you'll need to prevent your Swift Executable from closing yourself.
    /// If you want to run your Application indefinitely, or until your code shuts the application down, use `run()` instead.
    public func start() throws {
        try self.boot()
        let command = self.commands.group()
        var context = CommandContext(console: self.console, input: self.environment.commandInput)
        context.application = self
        try self.console.run(command, with: context)
    }

    public func boot() throws {
        guard !self.isBooted else {
            return
        }
        self.isBooted = true
        try self.lifecycle.handlers.forEach { try $0.willBoot(self) }
        try self.lifecycle.handlers.forEach { try $0.didBoot(self) }
    }
    
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

        self.didShutdown = true
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

public protocol LockKey { }
