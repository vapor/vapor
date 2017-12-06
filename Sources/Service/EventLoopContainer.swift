import Async
import Core
import Dispatch

/// A worker is any type that contains a reference
/// to an Event Loop.
// public protocol Worker: EventLoop, Container {}
//
///// A basic worker.
//public final class BasicWorker: Worker {
//    /// See Worker.eventLoop
//    public let eventLoop: EventLoop
//
//    /// See Worker.container
//    public let container: Container
//
//    /// See EventLoop.queue
//    public var queue: DispatchQueue {
//        return eventLoop.queue
//    }
//
//    /// See Container.config
//    public var config: Config {
//        return container.config
//    }
//
//    /// See Container.environment
//    public var environment: Environment {
//        return container.environment
//    }
//
//    /// See Container.services
//    public var services: Services {
//        return container.services
//    }
//
//    /// See Container.serviceCache
//    public var serviceCache: ServiceCache {
//        return container.serviceCache
//    }
//
//    /// Create a new basic worker
//    public init(eventLoop: EventLoop, container: Container) {
//        self.eventLoop = eventLoop
//        self.container = container
//    }
//}

