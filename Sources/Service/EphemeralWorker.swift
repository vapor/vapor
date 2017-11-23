import Async

/// Workers that are frequently created and
/// destroyed as an application does work.
public protocol EphemeralWorker: Worker, Extendable, HasContainer {
    /// Takes a self as input
    typealias LifecycleHook = (EphemeralWorker) -> ()

    /// Call this closure each time a new self is initailized.
    static var onInit: LifecycleHook? { get set }

    /// Call this closure each time an existing self is deinitialized.
    static var onDeinit: LifecycleHook? { get set }
}

public protocol EphemeralWorkerFindable {
    associatedtype EphemeralWorkerFindableResult
    static func find(identifier: String, for worker: EphemeralWorker) throws -> EphemeralWorkerFindableResult
}

/// Configures ephemeral workers.
public final class EphemeralWorkerConfig {
    /// Storage
    private var inits: [EphemeralWorker.LifecycleHook]
    private var deinits: [EphemeralWorker.LifecycleHook]
    private var workers: [EphemeralWorker.Type]

    /// Creates a new ephemeral worker config.
    public init() {
        self.inits = []
        self.deinits = []
        self.workers = []
    }

    /// Adds a new onInit lifecycle hook.
    public func onInit(_ onInit: @escaping EphemeralWorker.LifecycleHook) {
        inits.append(onInit)
        self.apply()
    }

    /// Adds a new onDeinit lifecycle hook.
    public func onDeinit(_ onDeinit: @escaping EphemeralWorker.LifecycleHook) {
        deinits.append(onDeinit)
        self.apply()
    }

    public func add(_ worker: EphemeralWorker.Type) {
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













