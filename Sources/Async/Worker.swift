import Dispatch

/// A worker is any type that contains a reference
/// to an Event Loop.
///
/// [Learn More →](http://docs.vapor.codes/3.0/async/worker/)
public protocol Worker {
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

extension DispatchQueue: Worker {
    /// See Worker.eventLoop
    public var eventLoop: EventLoop {
        return EventLoop(queue: self)
    }
}
