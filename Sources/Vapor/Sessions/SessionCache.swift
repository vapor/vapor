import Synchronization

/// Per-request session state, held by the ``Request`` for its lifetime.
internal final class SessionCache: Sendable {
    struct Storage: Sendable {
        /// The cached session.
        var session: Session? = nil

        /// Set to `true` when passing through ``SessionsMiddleware``.
        var middlewareFlag: Bool = false
    }

    let storage: Mutex<Storage>

    /// Creates a new `SessionCache`.
    init(session: Session? = nil) {
        self.storage = .init(.init(session: session))
    }
}
