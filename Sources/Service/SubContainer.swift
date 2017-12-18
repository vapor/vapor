import Async
import Dispatch

/// A container with reference to a super container.
public protocol SubContainer: Container {
    /// This container's parent container
    var superContainer: Container { get }
}

/// A basic container
public final class BasicSubContainer: SubContainer {
    /// See Container.config
    public var config: Config

    /// See Container.environment
    public var environment: Environment

    /// See Container.services
    public var services: Services

    /// See Container.serviceCache
    public var serviceCache: ServiceCache

    /// See SubContainer.superContainer
    public var superContainer: Container

    /// See Worker.eventLoop
    public var eventLoop: EventLoop

    /// Create a new basic container
    public init(config: Config, environment: Environment, services: Services, super: Container, on worker: Worker) {
        self.config = config
        self.environment = environment
        self.services = services
        self.serviceCache = .init()
        self.superContainer = `super`
        self.eventLoop = worker.eventLoop
    }
}

extension Container {
    /// Creates a sub container for this container.
    public func subContainer(on worker: Worker) -> BasicSubContainer {
        return BasicSubContainer(
            config: config,
            environment: environment,
            services: services,
            super: self,
            on: worker
        )
    }
}
