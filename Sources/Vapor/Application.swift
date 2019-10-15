import NIO

public final class Application {
    public var environment: Environment
    
    public let eventLoopGroup: EventLoopGroup
    
    public var userInfo: [AnyHashable: Any]
    
    public let sync: Lock
    
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

    public var providers: [Provider] {
        return self.services.providers
    }

    internal var cache: ServiceCache
    
    public struct Running {
        public var onStop: EventLoopFuture<Void>
        public var stop: () -> Void
        
        init(onStop: EventLoopFuture<Void>, stop: @escaping () -> Void) {
            self.onStop = onStop
            self.stop = stop
        }
    }
    
    public init(environment: Environment = .development) {
        self.environment = environment
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.userInfo = [:]
        self.didShutdown = false
        self.sync = Lock()
        self.threadPool = .init(numberOfThreads: 1)
        self.threadPool.start()
        self.logger = .init(label: "codes.vapor.application")
        self.services = .init()
        self.cache = .init()
    }

    public func make<S>(_ service: S.Type = S.self) throws -> S {
        assert(!self.didShutdown, "Container.shutdown() has been called, this Container is no longer valid.")

        // create service lookup identifier
        let id = ServiceID(S.self)

        // fetch service factory if one exists
        guard let factory = self.services.factories[id] as? ServiceFactory<S> else {
            throw Abort(.internalServerError, reason: "No service known for \(S.self)")
        }

        // check if cached
        switch factory.cache {
        case .application:
            self.sync.lock()
            if let cached = self.cache.get(service: S.self) {
                self.sync.unlock()
                return cached.service
            }
        case .container:
            if let cached = self.cache.get(service: S.self) {
                return cached.service
            }
        case .none: break
        }


        // create and extend the service
        var instance: S
        do {
            instance = try factory.boot(self)
            // check for any extensions
            if let extensions = self.services.extensions[id] as? [ServiceExtension<S>], !extensions.isEmpty {
                // loop over extensions, modifying instace
                try extensions.forEach { try $0.serviceExtend(&instance, self) }
            }
        } catch {
            // if creation fails, unlock application sync
            switch factory.cache {
            case .application:
                self.sync.unlock()
            default: break
            }
            throw error
        }

        // cache if needed
        let service = CachedService(service: instance, shutdown: factory.shutdown)
        switch factory.cache {
        case .application:
            self.cache.set(service: service)
            self.sync.unlock()
        case .container:
            self.cache.set(service: service)
        case .none: break
        }

        // return created and extended instance
        return instance
    }

    // MARK: Run

    public func boot() throws {
        try self.providers.forEach { try $0.willBoot(self) }
        try self.providers.forEach { try $0.didBoot(self) }
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
        let command = try self.make(Commands.self).group()
        let console = try self.make(Console.self)
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
