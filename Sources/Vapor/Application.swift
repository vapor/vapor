public protocol LockKey { }

public final class Application {
    public var environment: Environment
    public let eventLoopGroup: EventLoopGroup
    public var storage: Storage
    public var userInfo: [AnyHashable: Any]
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

    public init(_ environment: Environment = .development) {
        self.environment = environment
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.locks = .init()
        self.userInfo = [:]
        self.didShutdown = false
        self.logger = .init(label: "codes.vapor.application")
        self.storage = .init(logger: self.logger)
        self.lifecycle = .init()
        self.isBooted = false
        self.core.initialize()
        self.views.initialize()
        self.sessions.initialize()
        self.sessions.use(.memory)
        self.commands.use(self.server.command, as: "serve", isDefault: true)
        self.commands.use(RoutesCommand(), as: "routes")
        self.loadDotEnv()
    }
    
    public func run() throws {
        defer { self.shutdown() }
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
    
    private func loadDotEnv() {
        do {
            try DotEnvFile.load(
                path: ".env",
                fileio: .init(threadPool: self.threadPool),
                on: self.eventLoopGroup.next()
            ).wait()
        } catch {

            self.logger.debug("Could not load .env file: \(error)")
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
        self.userInfo = [:]

        self.logger.trace("Shutting down EventLoopGroup")
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            self.logger.error("Shutting down EventLoopGroup failed: \(error)")
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
