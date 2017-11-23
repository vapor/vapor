import Async
import Foundation


private let singletonCacheKey = "service:singleton-cache"
private let lockKey = "service:lock"

extension Container {
    /// Returns or creates a service for the given type.
    ///
    /// If a protocol is supplied, a service conforming
    /// to the protocol will be returned.
    public func make<Interface, Client>(
        _ interface: Interface.Type = Interface.self,
        for client: Client.Type
    ) throws -> Interface {
        // check if we've previously resolved this service
        if let service = try serviceCache.get(Interface.self, for: Client.self) {
            return service
        }

        do {
            // resolve the service and cache it
            let service = try unsafeMake(Interface.self, for: Client.self) as! Interface
            serviceCache.set(service, for: Client.self)
            return service
        } catch {
            // cache the error
            serviceCache.set(error: error, Interface.self, for: Client.self)
            throw error
        }
    }

    /// Returns or creates a service for the given type.
    /// If the service has already been requested once,
    /// the previous result for the interface and client is returned.
    ///
    /// This method accepts and returns Any.
    ///
    /// Use .make() for the safe method.
    internal func unsafeMake(
        _ interface: Any.Type,
        for client: Any.Type
    ) throws -> Any {
        return try uncachedUnsafeMake(interface, for: client)
    }

    /// Makes the interface for the client. Does not consult the service cache.
    fileprivate func uncachedUnsafeMake(
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
        var item: Any?

        let key = "\(chosen.serviceType)"
        if chosen.serviceIsSingleton, let cached = singletonCache[key] {
            item = cached
        } else {
            item = try chosen.makeService(for: self)
            if chosen.serviceIsSingleton {
                singletonCache[key] = item
            }
        }

        guard let ret = item else {
            throw ServiceError.incorrectType(
                type: chosen.serviceType,
                desired: interface
            )
        }

        return ret
    }

    fileprivate var singletonCache: [String: Any] {
        get { return extend[singletonCacheKey] as? [String: Any] ?? [:] }
        set { extend[singletonCacheKey] = newValue }
    }

    internal var lock: NSLock {
        if let existing = extend[lockKey] as? NSLock {
            return existing
        }
        let new = NSLock()
        extend[lockKey] = new
        return new
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
