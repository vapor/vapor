/// Services available for a service container.
public struct Services {
    var types: [ServiceType]
    var instances: [ServiceInstance]
    var providerTypes: [Provider.Type]
    var providers: [Provider]

    public init() {
        self.types = []
        self.instances = []
        self.providerTypes = []
        self.providers = []
    }
}

public struct ServiceType {
    var type: Service.Type
    var isSingleton: Bool
}

public struct ServiceInstance {
    var instance: Any
}

extension Services {
    /// Adds a service type to the Services.
    public mutating func register<S: Service>(
        _ type: S.Type = S.self,
        isSingleton: Bool = true
    ) {
        guard !types.contains(where: { $0.type == S.self }) else {
            return
        }

        let st = ServiceType(type: type, isSingleton: isSingleton)
        types.append(st)
    }

    /// Adds an instance of a service to the Services.
    public mutating func instance<S>(_ instance: S) {
        let si = ServiceInstance(instance: instance)
        instances.append(si)
    }

    /// Adds a Provider type to the Services.
    public mutating func provider<P: Provider>(_ p: P.Type) {
        guard !providerTypes.contains(where: { $0 == P.self }) else {
            return
        }

        providerTypes.append(P.self)
    }

    /// Adds a Provider to the Services.
    public mutating func provider<P: Provider>(_ p: P) {
        providers.append(p)
    }
}
