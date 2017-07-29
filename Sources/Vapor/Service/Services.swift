/// Services available for a service container.
public struct Services {
    var factories: [ServiceFactory]
    var providers: [ProviderFactory]

    public init() {
        self.factories = []
        self.providers = []
    }
}

// MARK: Services

extension Services {
    /// Adds a service type to the Services.
    public mutating func register<S: Service>(_ type: S.Type = S.self) {
        let factory = TypeServiceFactory(S.self)
        self.factory(factory)
    }

    /// Adds an instance of a service to the Services.
    public mutating func instance<S>(
        _ instance: S,
        name: String,
        supports: [Any.Type],
        isSingleton: Bool = true
    ) {
        let factory = BasicServiceFactory(S.self, name: name, supports: supports, isSingleton: isSingleton) { drop in
            return instance
        }
        self.factory(factory)
    }

    /// Adds any type conforming to ServiceFactory
    public mutating func factory(_ factory: ServiceFactory) {
        guard !factories.contains(where: {
            $0.serviceType == factory.serviceType && $0.serviceName == factory.serviceName
        }) else {
            return
        }
        
        factories.append(factory)
    }
}

// MARK: Provider

extension Services {
    /// Adds a Provider type to the Services.
    public mutating func provider<P: Provider>(_ p: P.Type) {
        let factory = TypeProviderFactory(P.self)
        self.provider(factory)
    }

    /// Adds a Provider to the Services.
    public mutating func provider<P: Provider>(_ p: P) {
        let factory = BasicProviderFactory(P.self) { config in
            return p
        }
        self.provider(factory)
    }

    public mutating func provider(_ factory: ProviderFactory) {
        guard !providers.contains(where: { $0.providerType == factory.providerType }) else {
            return
        }

        providers.append(factory)
    }
}
