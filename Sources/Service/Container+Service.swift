import Foundation

private let serviceCacheKey = "service:service-cache"

extension Container {
    /// Returns or creates a service for the given type.
    ///
    /// If a protocol is supplied, a service conforming
    /// to the protocol will be returned.
    public func make<Interface, Client>(
        _ interface: Interface.Type = Interface.self,
        for client: Client.Type
    ) throws -> Interface {
        return try unsafeMake(Interface.self, for: Client.self) as! Interface
    }

    /// Returns or creates a service for the given type.
    ///
    /// This method accepts and returns Any.
    ///
    /// Use .make() for the safe method.
    public func unsafeMake(
        _ interface: Any.Type,
        for client: Any.Type
    ) throws -> Any {
        // find all available service types that match the requested type.
        let available = services.factories(supporting: interface)

        let chosen: ServiceFactory

        if available.count > 1 {
            // multiple services are available,
            // we will need to disambiguate
            chosen = try config.choose(
                from: available,
                interface: interface,
                for: self,
                neededBy: client
            )
        } else if available.count == 0 {
            // no services are available matching
            // the type requested.
            throw ServiceError.noneAvailable(type: interface)
        } else {
            // only one service matches, no need to disambiguate.
            // let's use it!
            chosen = available[0]
        }

        try config.approve(
            chosen: chosen,
            interface: interface,
            for: self,
            neededBy: client
        )

        // lazy loading
        // create an instance of this service type.
        let item = try _makeServiceFactoryConsultingCache(chosen, ofType: interface)

        return item!
    }

    fileprivate func _makeServiceFactoryConsultingCache(
        _ serviceFactory: ServiceFactory, ofType type: Any.Type
    ) throws -> Any? {
        let key = "\(serviceFactory.serviceType)"
        if serviceFactory.serviceIsSingleton {
            if let cached = serviceCache[key] {
                return cached
            }
        }

        guard let new = try serviceFactory.makeService(for: self) else {
            throw ServiceError.incorrectType(
                type: serviceFactory.serviceType,
                desired: type
            )
        }

        if serviceFactory.serviceIsSingleton {
            serviceCache[key] = new
        }

        return new
    }

    fileprivate var serviceCache: [String: Any] {
        get {
            return extend[serviceCacheKey] as? [String: Any] ?? [:]
        }
        set {
            extend[serviceCacheKey] = newValue
        }
    }
}

// MARK: Service Utilities

extension Services {
    internal func factories(supporting interface: Any.Type) -> [ServiceFactory] {
        return factories.filter { factory in
            return factory.serviceType == interface || factory.serviceSupports.contains(where: { $0 == interface })
        }
    }
}
