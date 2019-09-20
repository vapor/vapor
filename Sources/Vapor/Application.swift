import NIO

public final class Application {
    public var environment: Environment
    
    public let eventLoopGroup: EventLoopGroup
    
    public var userInfo: [AnyHashable: Any]
    
    public let sync: Lock
    
    private let configure: (inout Services) throws -> ()
    
    public let threadPool: NIOThreadPool
    
    private var didShutdown: Bool

    public var running: Running? {
        get {
            self.sync.lock()
            defer { self.sync.unlock() }
            return self._running
        }
        set {
            self.sync.lock()
            defer { self.sync.unlock() }
            self._running = newValue
        }
    }
    
    private var _running: Running?
    
    public var logger: Logger

    public var services: Services

    internal var cache: ServiceCache
    
    public struct Running {
        public var onStop: EventLoopFuture<Void>
        public var stop: () -> Void
        
        init(onStop: EventLoopFuture<Void>, stop: @escaping () -> Void) {
            self.onStop = onStop
            self.stop = stop
        }
    }
    
    public init(
        environment: Environment = .development,
        configure: @escaping (inout Services) -> () = { _ in }
    ) {
        self.environment = environment
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.userInfo = [:]
        self.didShutdown = false
        self.configure = configure
        self.sync = Lock()
        self.threadPool = .init(numberOfThreads: 1)
        self.threadPool.start()
        self.logger = .init(label: "codes.vapor.application")
        var services = Services.default()
        configure(&services)
        self.services = services
        self.cache = .init()
    }

    public func makeContainer() -> EventLoopFuture<Container> {
        return self.makeContainer(on: self.eventLoopGroup.next())
    }
    
    public func makeContainer(on eventLoop: EventLoop) -> EventLoopFuture<Container> {
        return Container.boot(application: self, on: eventLoop)
    }

    // MARK: Run

    public func boot() throws {
        try self.services.providers.forEach { try $0.willBoot(self) }
        try self.services.providers.forEach { try $0.didBoot(self) }
    }
    
    public func run() throws {
        self.logger = .init(label: "codes.vapor.application")
        defer { self.shutdown() }
        do {
            try self.start()
            if let running = self.running {
                try running.onStop.wait()
            }
        } catch {
            self.logger.report(error: error)
            throw error
        }
    }
    
    public func start() throws {
        let eventLoop = self.eventLoopGroup.next()
        try self.loadDotEnv(on: eventLoop).wait()
        let c = try self.makeContainer(on: eventLoop).wait()
        defer { c.shutdown() }
        let command = try c.make(Commands.self).group()
        let console = try c.make(Console.self)
        try console.run(command, input: self.environment.commandInput)
    }
    
    
    private func loadDotEnv(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return DotEnvFile.load(
            path: ".env",
            fileio: .init(threadPool: self.threadPool),
            on: eventLoop
        ).recover { error in
            self.logger.debug("Could not load .env file: \(error)")
        }
    }
    
    public func shutdown() {
        self.logger.debug("Application shutting down")
        self.services.providers.forEach { $0.willShutdown(self) }
        self.cache.shutdown()
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            self.logger.error("EventLoopGroup failed to shutdown: \(error)")
        }
        do {
            try self.threadPool.syncShutdownGracefully()
        } catch {
            self.logger.error("ThreadPool failed to shutdown: \(error)")
        }
        self.didShutdown = true
        self.userInfo = [:]
    }
    
    deinit {
        if !self.didShutdown {
            assertionFailure("Application.shutdown() was not called before Application deinitialized.")
        }
    }
}
