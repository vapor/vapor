import NIOConcurrencyHelpers

/// Singleton service cache for a `Session`. Used with a message's private container.
internal final class SessionCache: Sendable {
    /// Set to `true` when passing through middleware.
    // This is only ever set in the middleware so doesn't need a lock
    let middlewareFlag: NIOLockedValueBox<Bool>

    /// The cached session.
    let session: NIOLockedValueBox<Session?>

    /// Creates a new `SessionCache`.
    init(session: Session? = nil) {
        self.session = .init(session)
        self.middlewareFlag = .init(false)
    }
}
