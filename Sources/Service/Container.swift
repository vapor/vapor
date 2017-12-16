import Async
import JunkDrawer
import Dispatch

/// Capable of creating instances of registered services.
/// This container makes use of config and environment
/// to determine which service instances are most appropriate to create.
public protocol Container: ServiceCacheable {
    var config: Config { get }
    var environment: Environment { get }
    var services: Services { get }
}

/// A basic container
public final class BasicContainer: Container {
    /// See Container.config
    public var config: Config

    /// See Container.environment
    public var environment: Environment

    /// See Container.services
    public var services: Services

    /// See Container.serviceCache
    public var serviceCache: ServiceCache

    /// Create a new basic container
    public init(config: Config, environment: Environment, services: Services) {
        self.config = config
        self.environment = environment
        self.services = services
        self.serviceCache = .init()
    }
}
