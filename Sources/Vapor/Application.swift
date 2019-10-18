public final class Application {
    public var environment: Environment
    public var services: Services
    public let sync: Lock
    public var userInfo: [AnyHashable: Any]
    public private(set) var didShutdown: Bool
    internal let eventLoopGroup: EventLoopGroup
    public var logger: Logger {
        return self._logger
    }
    private var _logger: Logger!

    public var providers: [Provider] {
        return self.services.providers
    }
    
    public init(environment: Environment = .development) {
        self.environment = environment
        self.services = .init()
        self.sync = .init()
        self.userInfo = [:]
        self.didShutdown = false
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.registerDefaultServices()
    }

    // MARK: Run

    public func boot() throws {
        self._logger = .init(label: "codes.vapor.application")
        try self.providers.forEach { try $0.willBoot(self) }
        try self.providers.forEach { try $0.didBoot(self) }
    }
    
    public func run() throws {
        defer { self.shutdown() }
        do {
            try self.start()
            try self.make(Running.self).current?.onStop.wait()
        } catch {
            try self.make(Logger.self).report(error: error)
            throw error
        }
    }
    
    public func start() throws {
        let eventLoop = try self.make(EventLoop.self)
        try self.loadDotEnv(on: eventLoop).wait()
        let command = try self.make(Commands.self).group()
        let console = try self.make(Console.self)
        try console.run(command, input: self.environment.commandInput)
    }
    
    
    private func loadDotEnv(on eventLoop: EventLoop) throws -> EventLoopFuture<Void> {
        let logger = try self.make(Logger.self)
        return try DotEnvFile.load(
            path: ".env",
            fileio: .init(threadPool: self.make()),
            on: eventLoop
        ).recover { error in
            logger.debug("Could not load .env file: \(error)")
        }
    }
    
    public func shutdown() {
        assert(!self.didShutdown, "Application has already shut down")
        self.logger.debug("Application shutting down")

        self.logger.trace("Notifying service providers of shutdown")
        self.services.providers.forEach { $0.willShutdown(self) }

        self.logger.trace("Shutting down services")
        self.services.shutdown()

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


public final class Running {
    public struct Current {
        public var onStop: EventLoopFuture<Void> {
            return self.promise.futureResult
        }

        let promise: EventLoopPromise<Void>

        public func stop() {
            self.promise.succeed(())
        }
    }
    
    public var current: Current? {
        return self._current
    }

    private var _current: Current?


    init() { }

    public func set(on eventLoop: EventLoop) -> EventLoopPromise<Void> {
        let promise = eventLoop.makePromise(of: Void.self)
        self._current = Current(promise: promise)
        return promise
    }
}

extension Application {
    public var running: Running {
        return try! self.make()
    }
}
