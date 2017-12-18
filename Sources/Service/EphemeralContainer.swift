import Async

/// Workers that are frequently created and
/// destroyed as an application does work.
public protocol EphemeralContainer: SubContainer {
    /// Takes a self as input
    typealias LifecycleHook = (EphemeralContainer) -> ()

    /// Call this closure each time a new self is initailized.
    static var onInit: LifecycleHook? { get set }

    /// Call this closure each time an existing self is deinitialized.
    static var onDeinit: LifecycleHook? { get set }

    /// A private container for storing things sensitive
    /// to this ephemeral container.
    var privateContainer: SubContainer { get }
}

/// The ephemeral container should act _as_ it's super container.
extension EphemeralContainer {
    /// See Worker.queue
    public var eventLoop: EventLoop {
        return superContainer.eventLoop
    }

    /// See Container.config
    public var config: Config {
        return superContainer.config
    }

    /// See Container.environment
    public var environment: Environment {
        return superContainer.environment
    }

    /// See Container.services
    public var services: Services {
        return superContainer.services
    }

    /// See Container.serviceCache
    public var serviceCache: ServiceCache {
        return superContainer.serviceCache
    }
}

public protocol ContainerFindable {
    associatedtype ContainerFindableResult
    static func find(identifier: String, using container: Container) throws -> ContainerFindableResult
}

/// Configures ephemeral workers.
public final class EphemeralWorkerConfig {
    /// Storage
    private var inits: [EphemeralContainer.LifecycleHook]
    private var deinits: [EphemeralContainer.LifecycleHook]
    private var workers: [EphemeralContainer.Type]

    /// Creates a new ephemeral worker config.
    public init() {
        self.inits = []
        self.deinits = []
        self.workers = []
    }

    /// Adds a new onInit lifecycle hook.
    public func onInit(_ onInit: @escaping EphemeralContainer.LifecycleHook) {
        inits.append(onInit)
        self.apply()
    }

    /// Adds a new onDeinit lifecycle hook.
    public func onDeinit(_ onDeinit: @escaping EphemeralContainer.LifecycleHook) {
        deinits.append(onDeinit)
        self.apply()
    }

    public func add(_ worker: EphemeralContainer.Type) {
        workers.append(worker)
        self.apply()
    }

    /// Applys lifecycle hooks to all workers.
    private func apply() {
        let inits = self.inits
        let deinits = self.deinits

        for worker in workers {
            worker.onInit = { worker in
                inits.forEach( { $0(worker) })
            }
            worker.onDeinit = { worker in
                deinits.forEach( { $0(worker) })
            }
        }
    }
}
