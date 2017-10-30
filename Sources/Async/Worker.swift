import Dispatch

/// A worker is any type that contains a reference
/// to an Event Loop.
public protocol Worker: Extendable {
    /// The event loop to execute this
    /// worker's tasks on.
    var eventLoop: EventLoop { get }
}

extension EventLoop: Worker {
    /// See Worker.eventLoop
    public var eventLoop: EventLoop {
        return self
    }
}
