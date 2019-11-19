public final class Application {
    public var environment: Environment
    public var services: Services
    public let sync: Lock
    public var userInfo: [AnyHashable: Any]
    public private(set) var didShutdown: Bool
    internal let eventLoopGroup: EventLoopGroup
    public var logger: Logger
    private var isBooted: Bool

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
        self.logger = .init(label: "codes.vapor.application")
        self.isBooted = false
        self.registerDefaultServices()
    }

    // MARK: Run
    
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
        let command = self.make(Commands.self).group()
        let console = self.make(Console.self)
        try console.run(command, input: self.environment.commandInput)
    }

    public func boot() throws {
        guard !self.isBooted else {
            return
        }
        self.isBooted = true
        try self.providers.forEach { try $0.willBoot(self) }
        try self.providers.forEach { try $0.didBoot(self) }
    }
    
    public func loadDotEnv(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        let directoryConfig = DirectoryConfiguration.detect()
        return DotEnvFile.load(
            path: directoryConfig.workingDirectory + ".env",
            fileio: .init(threadPool: self.make()),
            on: eventLoop
        ).recover { error in
            self.logger.debug("Could not load .env file: \(error)")
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


extension Application {
    public var running: Running? {
        get {
            return self.make(RunningService.self).current
        }
        set {
            self.make(RunningService.self).current = newValue
        }
    }
}


public struct Running {
    public static func start(using promise: EventLoopPromise<Void>) -> Running {
        return self.init(promise: promise)
    }
    
    public var onStop: EventLoopFuture<Void> {
        return self.promise.futureResult
    }

    private let promise: EventLoopPromise<Void>

    public func stop() {
        self.promise.succeed(())
    }
}

final class RunningService {
    var current: Running?
    init() { }
}
