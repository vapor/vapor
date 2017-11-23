import Async

/// Capable of creating instances of registered services.
/// This container makes use of config and environment
/// to determine which service instances are most appropriate to create.
public protocol Container: ServiceCacheable, Extendable {
    var config: Config { get }
    var environment: Environment { get }
    var services: Services { get }
}

/// Has a pointer to a container.
/// FIXME: this name is awful!
public protocol HasContainer {
    var container: Container? { get }
}

extension HasContainer {
    /// Returns a container or throws an error if none exists.
    public func requireContainer() throws -> Container {
        guard let container = self.container else {
            throw "container required"
        }
        return container
    }
}

// MARK: Async

extension EventLoop: HasContainer {
    /// See HasContainer.container
    public var container: Container? {
        get { return extend["vapor:container"] as? Container }
        set { extend["vapor:container"] = newValue }
    }
}
