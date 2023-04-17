import Backtrace
import NIOConcurrencyHelpers
import NIOCore
import Logging
import ConsoleKit
import NIOPosix

/// Core type representing a Vapor application.
/// This is Sendable because all mutable properties are protected by locks
public final class Application: @unchecked Sendable {
    public var environment: Environment {
        get {
            environmentLock.withLock {
                return _environment
            }
        }
        set {
            environmentLock.withLockVoid {
                _environment = newValue
            }
        }
    }
    
    public var storage: Storage {
        get {
            storageLock.withLock {
                return _storage
            }
        }
        set {
            storageLock.withLockVoid {
                _storage = newValue
            }
        }
    }
    
    public var didShutdown: Bool {
        shutdownLock.withLock {
            return _didShutdown
        }
    }
    
    public var logger: Logger {
        get {
            loggerLock.withLock {
                return _logger
            }
        }
        set {
            loggerLock.withLockVoid {
                _logger = newValue
            }
        }
    }
    
    public let eventLoopGroupProvider: EventLoopGroupProvider
    public let eventLoopGroup: EventLoopGroup
    var isBooted: Bool {
        get {
            isBootedLock.withLock {
                return _isBooted
            }
        }
        set {
            isBootedLock.withLockVoid {
                _isBooted = newValue
            }
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
            lifecycleLock.withLock {
                return _lifecycle
            }
        }
        set {
            lifecycleLock.withLockVoid {
                _lifecycle = newValue
            }
        }
    }

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
            self.main.withLock { self.storage.insertOrReturn(.init(), at: .init(Key.self)) }
        }
    }

    public var locks: Locks {
        get {
            locksLock.withLock {
                return _locks
            }
        }
        set {
            locksLock.withLockVoid {
                locks = newValue
            }
        }
    }

    public var sync: NIOLock {
        self.locks.main
    }
    
    public enum EventLoopGroupProvider: Sendable {
        case shared(EventLoopGroup)
        case createNew
    }
    
    private let environmentLock: NIOLock
    private let storageLock: NIOLock
    private let shutdownLock: NIOLock
    private let loggerLock: NIOLock
    private let isBootedLock: NIOLock
    private let lifecycleLock: NIOLock
    private let locksLock: NIOLock
    
    private var _environment: Environment
    private var _storage: Storage
    private var _didShutdown: Bool
    private var _logger: Logger
    private var _isBooted: Bool
    private var _lifecycle: Lifecycle
    private var _locks: Locks

    public init(
        _ environment: Environment = .development,
        _ eventLoopGroupProvider: EventLoopGroupProvider = .createNew
    ) {
        Backtrace.install()
        self._environment = environment
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        }
        self._locks = .init()
        
        self.environmentLock = .init()
        self.storageLock = .init()
        self.shutdownLock = .init()
        self.loggerLock = .init()
        self.isBootedLock = .init()
        self.lifecycleLock = .init()
        self.locksLock = .init()
        
        self._didShutdown = false
        self._logger = .init(label: "codes.vapor.application")
        self._storage = .init(logger: self._logger)
        self._lifecycle = .init()
        self._isBooted = false
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
    
    /// Starts the Application using the `start()` method, then waits for any running tasks to complete
    /// If your application is started without arguments, the default argument is used.
    ///
    /// Under normal circumstances, `run()` begin start the shutdown, then wait for the web server to (manually) shut down before returning.
    public func run() throws {
        do {
            try self.start()
            try self.running?.onStop.wait()
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

        self._didShutdown = true
        self.logger.trace("Application shutdown complete")
    }
    
    deinit {
        self.logger.trace("Application deinitialized, goodbye!")
        if !self._didShutdown {
            self.logger.error("Application.shutdown() was not called before Application deinitialized.")
            self.shutdown()
        }
    }
}

public protocol LockKey { }

fileprivate extension Dictionary {
    mutating func insertOrReturn(_ value: @autoclosure () -> Value, at key: Key) -> Value {
        if let existing = self[key] {
            return existing
        }
        let newValue = value()
        self[key] = newValue
        return newValue
    }
}
