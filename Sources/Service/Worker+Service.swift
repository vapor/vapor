import Async

private let serviceCacheKey = "service:service-cache"

extension EventLoop: ServiceCacheable {
    /// See ServiceCacheable.serviceCache
    public var serviceCache: ServiceCache {
        if let existing = extend[serviceCacheKey] as? ServiceCache {
            return existing
        }
        let new = ServiceCache()
        extend[serviceCacheKey] = new
        return new
    }
}

//extension EphemeralWorker {
//    /// Returns or creates a service for the given type.
//    ///
//    /// If a protocol is supplied, a service conforming
//    /// to the protocol will be returned.
//    public func make<Interface, Client>(
//        _ interface: Interface.Type = Interface.self,
//        for client: Client.Type
//    ) throws -> Interface {
//        // check if we've previously resolved this service
//        if let service = try eventLoop.serviceCache.get(Interface.self, for: Client.self) {
//            return service
//        }
//
//        do {
//            // resolve the service and cache it
//            let service = try unsafeMake(Interface.self, for: Client.self) as! Interface
//            eventLoop.serviceCache.set(service, for: Client.self)
//            return service
//        } catch {
//            // cache the error
//            eventLoop.serviceCache.set(error: error, Interface.self, for: Client.self)
//            throw error
//        }
//    }
//
//    /// Returns or creates a service for the given type.
//    /// If the service has already been requested once,
//    /// the previous result for the interface and client is returned.
//    ///
//    /// This method accepts and returns Any.
//    ///
//    /// Use .make() for the safe method.
//    fileprivate func unsafeMake(
//        _ interface: Any.Type,
//        for client: Any.Type
//    ) throws -> Any {
//        /// require the worker's container
//        let container = try requireContainer()
//
//        /// locking is required here so that we don't
//        /// run into threading issues with the shared container.
//        /// however, the lock will only be hit on the first request,
//        /// so it should't be a huge issue.
//        container.lock.lock()
//        defer {
//            container.lock.unlock()
//        }
//
//        /// use the container to create the service
//        return try unsafeMake(interface, for: client)
//    }
//}

