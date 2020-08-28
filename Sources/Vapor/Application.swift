import Backtrace

public final class Application {
    public var environment: Environment
    public let eventLoopGroupProvider: EventLoopGroupProvider
    public let eventLoopGroup: EventLoopGroup
    public var storage: Storage
    public private(set) var didShutdown: Bool
    public var logger: Logger
    private var isBooted: Bool

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
        public let main: Lock
        var storage: [ObjectIdentifier: Lock]

        init() {
            self.main = .init()
            self.storage = [:]
        }

        public func lock<Key>(for key: Key.Type) -> Lock
            where Key: LockKey
        {
            self.main.lock()
            defer { self.main.unlock() }
            if let existing = self.storage[ObjectIdentifier(Key.self)] {
                return existing
            } else {
                let new = Lock()
                self.storage[ObjectIdentifier(Key.self)] = new
                return new
            }
        }
    }

    public var locks: Locks

    public var sync: Lock {
        self.locks.main
    }
    
    public enum EventLoopGroupProvider {
        case shared(EventLoopGroup)
        case createNew
    }

    public init(
        _ environment: Environment = .init(name: .development),
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
        // Load specific .env first since values are not overridden.
        self.loadDotEnv(named: ".env.\(self.environment.name)")
        self.loadDotEnv(named: ".env")
    }
    
    public func run() throws {
        do {
            try self.start()
            try self.running?.onStop.wait()
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }
    
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
    
    private func loadDotEnv(named name: String) {
        do {
            try DotEnvFile.load(
                path: name,
                fileio: .init(threadPool: self.threadPool),
                on: self.eventLoopGroup.next()
            ).wait()
        } catch {
            self.logger.debug("Could not load \(name) file: \(error)")
        }
    }
    
    public func shutdown() {
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Shutting down providers")
        self.lifecycle.handlers.forEach { $0.shutdown(self) }
        self.lifecycle.handlers = []
        
        self.logger.trace("Clearing Application storage")
        self.storage.shutdown()
        self.storage.clear()

        switch self.eventLoopGroupProvider {
        case .shared:
            self.logger.trace("Running on shared EventLoopGroup. Not shutting down EventLoopGroup")
        case .createNew:
            self.logger.trace("Shutting down EventLoopGroup")
            do {
                try self.eventLoopGroup.syncShutdownGracefully()
            } catch {
                self.logger.error("Shutting down EventLoopGroup failed: \(error)")
            }
        }

        self.didShutdown = true
        self.logger.trace("Application shutdown complete")
    }
    
    deinit {
        self.logger.trace("Application deinitialized, goodbye!")
        if !self.didShutdown {
            assertionFailure("Application.shutdown() was not called before Application deinitialized.")
        }
    }
}

public protocol LockKey { }
