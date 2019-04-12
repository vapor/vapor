public final class Container {
    public static func boot(environment: Environment = .development, services: Services, on eventLoop: EventLoop) -> EventLoopFuture<Container> {
        let container = Container(environment: environment, services: services, on: eventLoop)
        return container.willBoot()
            .flatMap { container.didBoot() }
            .map { container }
    }
    
    /// Service `Environment` (e.g., production, dev). Use this to dynamically swap services based on environment.
    public let environment: Environment
    
    /// Available services. This struct contains all of this `Container`'s available service implementations.
    public let services: Services
    
    /// All `Provider`s that have been registered to this `Container`'s `Services`.
    public var providers: [Provider] {
        return self.services.providers
    }
    
    /// This container's event loop.
    public let eventLoop: EventLoop
    
    /// Stores cached singleton services.
    private var cache: ServiceCache
    
    private var didShutdown: Bool
    
    private init(environment: Environment, services: Services, on eventLoop: EventLoop) {
        self.environment = environment
        self.services = services
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
        
        // check if cached
        if let cached = self.cache.get(service: S.self) {
            return cached
        }
        
        // create service lookup identifier
        let id = ServiceID(S.self)
        
        // fetch service factory if one exists
        guard let factory = self.services.factories[id] as? ServiceFactory<S> else {
            fatalError("No services available for \(S.self)")
        }
        
        // create the service
        var instance = try factory.serviceMake(for: self)
        
        // check for any extensions
        if let extensions = self.services.extensions[id] as? [ServiceExtension<S>], !extensions.isEmpty {
            // loop over extensions, modifying instace
            try extensions.forEach { try $0.serviceExtend(&instance, self) }
        }
        
        // cache if singleton
        if factory.isSingleton {
            self.cache.set(service: instance)
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
        self.cache.clear()
        self.didShutdown = true
    }
    
    deinit {
        assert(self.didShutdown, "Container.shutdown() was not called before Container deinitialized")
    }
}
