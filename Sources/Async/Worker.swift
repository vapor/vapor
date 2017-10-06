import Dispatch

/// An event loop with context.
public final class Worker: Extendable {
    /// This worker's event loop
    public let queue: DispatchQueue

    /// Allows the worker to be extended
    public var extend: Extend

    /// Create a new worker.
    public init(queue: DispatchQueue) {
        self.queue = queue
        self.extend = Extend()
    }
}
