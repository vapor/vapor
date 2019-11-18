public final class Application {
    public var environment: Environment
    public private(set) var providers: [Provider]
    public let eventLoopGroup: EventLoopGroup
    public let sync: Lock
    public var userInfo: [AnyHashable: Any]
    public private(set) var didShutdown: Bool
    public var logger: Logger
    private var isBooted: Bool
    
    
    public init(environment: Environment = .development) {
        self.environment = environment
        self.providers = []
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.sync = .init()
        self.userInfo = [:]
        self.didShutdown = false
        self.logger = .init(label: "codes.vapor.application")
        self.isBooted = false
        self.use(Core())
    }

    public func use(_ provider: Provider) {
        self.providers.append(provider)
        provider.register(self)
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
        let eventLoop = self.eventLoopGroup.next()
        try self.loadDotEnv(on: eventLoop).wait()
        let command = try! self.commands.resolve().group()
        try self.console.run(command, input: self.environment.commandInput)
    }

    public func boot() throws {
        guard !self.isBooted else {
            return
        }
        self.isBooted = true
        try self.providers.forEach { try $0.willBoot(self) }
        try self.providers.forEach { try $0.didBoot(self) }
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
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Shutting down providers")
        self.providers.forEach { $0.willShutdown(self) }

        self.logger.trace("Clearing Application.userInfo")
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
