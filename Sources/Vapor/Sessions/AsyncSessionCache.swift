/// Singleton service cache for an `AsyncSession`. Used with a message's private container.
internal final class AsyncSessionCache {
    /// Set to `true` when passing through middleware.
    var middlewareFlag: Bool

    /// The cached session.
    var session: AsyncSession?

    /// Creates a new `SessionCache`.
    init(session: AsyncSession? = nil) {
        self.session = session
        self.middlewareFlag = false
    }
}
