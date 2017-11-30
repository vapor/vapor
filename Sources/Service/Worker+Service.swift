import Async

private let serviceCacheKey = "service:service-cache"

// FIXME: make this more performant

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
