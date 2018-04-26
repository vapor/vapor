/// Servers are capable of binding to an address and subsequently responding to requests sent to that address.
public protocol Server {
    /// Starts the `Server`.
    ///
    /// Upon starting, the `Server` must set the application's `runningServer` property.
    ///
    /// - parameters:
    ///     - hostname: Optional hostname override.
    ///                 If set, the server should bind to this hostname instead of its configured hostname.
    ///     - port: Optional port override.
    ///             If set, the server should bind to this port instead of its configured port.
    /// - returns: A future notification that will complete when the `Server` has started successfully.
    func start(hostname: String?, port: Int?) -> Future<Void>
}

extension Application {
    /// Stores a reference to the `Application`'s currently running server.
    public var runningServer: RunningServer? {
        get {
            guard let cache = try? self.make(RunningServerCache.self) else {
                return nil
            }
            return cache.storage
        }
        set {
            guard let cache = try? self.make(RunningServerCache.self) else {
                return
            }
            cache.storage = newValue
        }
    }
}

/// A context for the currently running `Server` protocol. When a `Server` succesfully boots,
/// it sets one of these on the `runningServer` property of the `Application`.
///
/// This struct can be used to close the server.
///
///     try app.runningServer?.close().wait()
///
/// It can also be used to wait until something else closes the server.
///
///     try app.runningServer?.onClose().wait()
///
public struct RunningServer {
    /// A future that will be completed when the server closes.
    public let onClose: Future<Void>

    /// Stops the currently running server, if one is running.
    public let close: () -> Future<Void>
}

/// MARK: Private

/// Reference-type wrapper around a `RunningServer`.
final class RunningServerCache: Service {
    /// The stored `RunningServer`.
    var storage: RunningServer?

    /// Creates a new `RunningServerCache`.
    init() { storage = nil }
}
