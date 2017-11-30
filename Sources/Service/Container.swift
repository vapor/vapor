import Async

/// Capable of creating instances of registered services.
/// This container makes use of config and environment
/// to determine which service instances are most appropriate to create.
public protocol Container: Extendable, ServiceCacheable, Worker {
    var config: Config { get }
    var environment: Environment { get }
    var services: Services { get }
}
