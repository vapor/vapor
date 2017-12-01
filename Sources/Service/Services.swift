import Async

/// Services available for a service container.
public struct Services {
    var factories: [ServiceFactory]
    public internal(set) var providers: [Provider]

    public init() {
        self.factories = []
        self.providers = []
    }
}

// MARK: Services

extension Services {
    /// Adds a service type to the Services.
    public mutating func register<S: ServiceType>(_ type: S.Type = S.self) {
        let factory = TypeServiceFactory(S.self)
        self.register(factory)
    }

    /// Adds an instance of a service to the Services.
    public mutating func register<S>(
        _ interface: Any.Type,
        tag: String? = nil,
        _ instance: S
    ) {
        return register(supports: [interface], tag: tag, instance)
    }

    /// Adds an instance of a service to the Services.
    public mutating func register<S>(
        supports: [Any.Type] = [],
        tag: String? = nil,
        _ instance: S
    ) {
        let factory = BasicServiceFactory(
            S.self,
            tag: tag,
            supports: supports
        ) { container in
            return instance
        }
        self.register(factory)
    }

    /// Adds any type conforming to ServiceFactory
    public mutating func register(_ factory: ServiceFactory) {
        if let existing = factories.index(where: {
            $0.serviceType == factory.serviceType
        }) {
            factories[existing] = factory
        } else {
            factories.append(factory)
        }
    }

    /// Adds a closure based service factory
    public mutating func register<S>(
        _ supports: [Any.Type] = [],
        tag: String? = nil,
        factory: @escaping (Container) throws -> (S)
    ) {
        let factory = BasicServiceFactory(
            S.self,
            tag: tag,
            supports: supports
        ) { worker in
            try factory(worker)
        }
        self.register(factory)
    }

    /// Adds a closure based service factory
    public mutating func register<S>(
        _ interface: Any.Type,
        tag: String? = nil,
        factory: @escaping (Container) throws -> (S)
    ) {
        let factory = BasicServiceFactory(
            S.self,
            tag: tag,
            supports: [interface]
        ) { worker in
            try factory(worker)
        }
        self.register(factory)
    }

    /// Adds an initialized provider
    public mutating func register<P: Provider>(_ provider: P) throws {
        guard !providers.contains(where: { Swift.type(of: $0) == P.self }) else {
            return
        }
        try provider.register(&self)
        providers.append(provider)
    }
}
