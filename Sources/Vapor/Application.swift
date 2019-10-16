public final class Application {
    public var environment: Environment
    public var services: Services
    public let sync: Lock
    public var userInfo: [AnyHashable: Any]
    internal var cache: ServiceCache
    private var didShutdown: Bool

    public var providers: [Provider] {
        return self.services.providers
    }
    
    public init(environment: Environment = .development) {
        self.environment = environment
        self.services = .init()
        self.sync = .init()
        self.userInfo = [:]
        self.cache = .init()
        self.didShutdown = false
        self.serviceLocks = [:]
        self.registerDefaultServices()
    }

    // MARK: Services

    var serviceLocks: [ServiceID: Lock]

    public func make<S>(_ service: S.Type = S.self) throws -> S {
        assert(!self.didShutdown, "Application.shutdown() has been called, this Application is no longer valid.")

        // create service lookup identifier
        let id = ServiceID(S.self)

        let serviceLock: Lock
        self.sync.lock()
        if let existing = self.serviceLocks[id] {
            serviceLock = existing
        } else {
            let new = Lock()
            self.serviceLocks[id] = new
            serviceLock = new
        }
        self.sync.unlock()

        // fetch service factory if one exists
        guard let factory = self.services.factories[id] as? ServiceFactory<S> else {
            throw Abort(.internalServerError, reason: "No service known for \(S.self)")
        }

        // check if cached
        switch factory.cache {
        case .singleton:
            serviceLock.lock()
            if let cached = self.cache.get(service: S.self) {
                serviceLock.unlock()
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
            case .singleton:
                serviceLock.unlock()
            case .none: break
            }
            throw error
        }

        // cache if needed
        let service = CachedService(service: instance, shutdown: factory.shutdown)
        switch factory.cache {
        case .singleton:
            self.cache.set(service: service)
            serviceLock.unlock()
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
        try! self.make(Logger.self).debug("Application shutting down")
        self.services.providers.forEach { $0.willShutdown(self) }
        self.cache.shutdown()
        self.userInfo = [:]
        self.didShutdown = true
    }
    
    deinit {
        if !self.didShutdown {
            assertionFailure("Application.shutdown() was not called before Application deinitialized.")
        }
    }
}


public final class Running {
    public struct Current {
        public let onStop: EventLoopFuture<Void>
        public let stop: () -> Void
    }

    let lock: Lock
    
    public var current: Current? {
        get {
            return self._current.map { current in
                Current(onStop: current.onStop) {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    current.stop()
                }
            }
        }
        set {
            self._current = newValue
        }
    }

    private var _current: Current?

    public init(lock: Lock) {
        self.lock = lock
    }
}
