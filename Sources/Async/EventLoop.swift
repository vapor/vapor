import Dispatch

/// An event loop with context.
///
/// [Learn More →](https://docs.vapor.codes/3.0/concepts/async/)
public final class EventLoop: Extendable {
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

// MARK: Default
private let _default = EventLoop(queue: .global())

extension EventLoop {
    public static var `default`: EventLoop { return _default }
}
