/// Singleton service cache for a `Session`. Used with a message's private container.
internal final class SessionCache: ServiceType {
    /// See `ServiceType`.
    static func makeService(for worker: Container) throws -> SessionCache {
        return .init()
    }

    /// Set to `true` when passing through middleware.
    var middlewareFlag: Bool

    /// The cached session.
    var session: Session?

    /// Creates a new `SessionCache`.
    init(session: Session? = nil) {
        self.session = session
        self.middlewareFlag = false
    }
}
