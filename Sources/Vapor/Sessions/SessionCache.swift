import NIOConcurrencyHelpers

/// Singleton service cache for a `Session`. Used with a message's private container.
internal final class SessionCache: @unchecked Sendable {
    /// Set to `true` when passing through middleware.
    // This is only ever set in the middleware so doesn't need a lock
    var middlewareFlag: Bool

    /// The cached session.
    var session: Session? {
        get {
            sessionLock.withLock {
                return _session
            }
        }
        set {
            sessionLock.withLockVoid {
                _session = newValue
            }
        }
    }
    
    private let sessionLock: NIOLock
    private var _session: Session?

    /// Creates a new `SessionCache`.
    init(session: Session? = nil) {
        self._session = session
        self.sessionLock = .init()
        self.middlewareFlag = false
    }
}
