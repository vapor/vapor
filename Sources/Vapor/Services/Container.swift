public final class Container {
    static func boot(
        application: Application,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<Container> {
        let container = Container(application: application, on: eventLoop)
        return container.willBoot()
            .flatMap { container.didBoot() }
            .map { container }
    }

    public let application: Application

    /// Service `Environment` (e.g., production, dev). Use this to dynamically swap services based on environment.
    public var environment: Environment {
        return self.application.environment
    }
    
    /// Available services. This struct contains all of this `Container`'s available service implementations.
    public var services: Services {
        return self.application.services
    }
    
    /// All `Provider`s that have been registered to this `Container`'s `Services`.
    public var providers: [Provider] {
        return self.services.providers
    }
    
    /// This container's event loop.
    public let eventLoop: EventLoop
    
    /// Stores cached singleton services.
    private var cache: ServiceCache
    
    private var didShutdown: Bool
    
    private init(
        application: Application,
        on eventLoop: EventLoop
    ) {
        self.application = application
        self.eventLoop = eventLoop
        self.cache = .init()
        self.didShutdown = false
    }
    
    /// Creates a service for the supplied interface or type.
    ///
    ///     let redis = try container.make(RedisCache.self)
    ///
    /// If a protocol is supplied, a service conforming to the protocol will be returned.
    ///
    ///     let client = try container.make(Client.self)
    ///     print(type(of: client)) // EngineClient
    ///
    /// Subsequent calls to `make(_:)` for the same type will yield a cached result.
    ///
    /// - parameters:
    ///     - type: Service or interface type `T` to create.
    /// - throws: Any error finding or initializing the requested service.
    /// - returns: Initialized instance of `T`
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
            self.application.sync.lock()
            if let cached = self.application.cache.get(service: S.self) {
                self.application.sync.unlock()
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
                self.application.sync.unlock()
            default: break
            }
            throw error
        }

        // cache if needed
        let service = CachedService(service: instance, shutdown: factory.shutdown)
        switch factory.cache {
        case .application:
            self.application.cache.set(service: service)
            self.application.sync.unlock()
        case .container:
            self.cache.set(service: service)
        case .none: break
        }

        // return created and extended instance
        return instance
    }
    
    private func willBoot() -> EventLoopFuture<Void> {
        return .andAllSucceed(self.providers.map { $0.willBoot(self) }, on: self.eventLoop)
    }
    
    private func didBoot() -> EventLoopFuture<Void> {
        return .andAllSucceed(self.providers.map { $0.didBoot(self) }, on: self.eventLoop)
    }
    
    public func shutdown() {
        for provider in self.providers {
            provider.willShutdown(self)
        }
        self.cache.shutdown()
        self.didShutdown = true
    }
    
    deinit {
        assert(self.didShutdown, "Container.shutdown() was not called before Container deinitialized")
    }
}
