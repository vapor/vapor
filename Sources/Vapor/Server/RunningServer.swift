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

/// A context for the currently running `Server` protocol. When a `Server` successfully boots,
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

/// MARK: Internal

/// Reference-type wrapper around a `RunningServer`.
internal final class RunningServerCache: ServiceType {
    /// See `ServiceType`.
    static func makeService(for worker: Container) throws -> RunningServerCache {
        return .init()
    }

    /// The stored `RunningServer`.
    var storage: RunningServer?

    /// Creates a new `RunningServerCache`.
    private init() { }
}
