import Async
import Foundation

public final class ServiceCache {
    public init() {}
    
    fileprivate subscript(serviceFor interface: Any.Type, client: Any.Type) -> ResolvedService? {
        get {
            return self.cache[(ObjectIdentifier(interface).hashValue &+ 31) &+ ObjectIdentifier(client).hashValue]
        }
        set {
            self.cache[(ObjectIdentifier(interface).hashValue &+ 31) &+ ObjectIdentifier(client).hashValue] = newValue
        }
    }
    
    fileprivate subscript(singletonFor type: Any.Type) -> Any? {
        get {
            return self.singletons[ObjectIdentifier(type)]
        }
        set {
            self.singletons[ObjectIdentifier(type)] = newValue
        }
    }
    
    fileprivate var cache = [Int: ResolvedService]()
    fileprivate var singletons = [ObjectIdentifier: Any]()
}

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
    /// If the service has already been requested once,
    /// the previous result for the interface and client is returned.
    ///
    /// This method accepts and returns Any.
    ///
    /// Use .make() for the safe method.
    fileprivate func unsafeMake(
        _ interface: Any.Type,
        for client: Any.Type
    ) throws -> Any {
        // check if we've previously resolved this service
        if let service = cache[serviceFor: interface, client] {
            return try service.resolve()
        }

        // resolve the service and cache it
        let result: ResolvedService
        do {
            let service = try uncachedUnsafeMake(interface, for: client)
            result = .service(service)
        } catch {
            result = .error(error)
        }
        
        self.cache[serviceFor: interface, client] = result

        // return the newly cached service
        return try result.resolve()
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

        if chosen.serviceIsSingleton, let cached = self.cache[singletonFor: chosen.serviceType] {
            item = cached
        } else {
            item = try chosen.makeService(for: self)
            if chosen.serviceIsSingleton {
                self.cache[singletonFor: chosen.serviceType] = item
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
}

// MARK: Service Utilities

extension Services {
    internal func factories(supporting interface: Any.Type) -> [ServiceFactory] {
        return factories.filter { factory in
            return factory.serviceType == interface || factory.serviceSupports.contains(where: { $0 == interface })
        }
    }
}

extension HasContainer {
    /// Returns or creates a service for the given type.
    ///
    /// If a protocol is supplied, a service conforming
    /// to the protocol will be returned.
    public func make<Interface, Client>(
        _ interface: Interface.Type = Interface.self,
        for client: Client.Type
    ) throws -> Interface {
        return try unsafeWorkerMake(Interface.self, for: Client.self) as! Interface
    }

    /// Returns or creates a service for the given type.
    /// If the service has already been requested once,
    /// the previous result for the interface and client is returned.
    ///
    /// This method accepts and returns Any.
    ///
    /// Use .make() for the safe method.
    fileprivate func unsafeWorkerMake(
        _ interface: Any.Type,
        for client: Any.Type
    ) throws -> Any {
        /// require the worker's container
        let container = try requireContainer()
        
        // check if we've previously resolved this service
        if let service = container.cache[serviceFor: interface, client] {
            return try service.resolve()
        }
        
        /// locking is required here so that we don't
        /// run into threading issues with the shared container.
        /// however, the lock will only be hit on the first request,
        /// so it should't be a huge issue.
        _containerLock.lock()
        defer {
            _containerLock.unlock()
        }
        
        // resolve the service and cache it
        let result: ResolvedService
        do {
            let service = try container.uncachedUnsafeMake(interface, for: client)
            result = .service(service)
        } catch {
            result = .error(error)
        }

        container.cache[serviceFor: interface, client] = result

        // return the newly cached service
        return try result.resolve()
    }
}

let _containerLock = NSLock()

fileprivate enum ResolvedService {
    case service(Any)
    case error(Error)

    func resolve() throws -> Any {
        switch self {
        case .error(let error): throw error
        case .service(let service): return service
        }
    }
}
