extension Request {
    /// Returns the current `Session` or creates one.
    ///
    ///     router.get("session") { req -> String in
    ///         req.session.data["name"] = "Vapor"
    ///         return "Session set"
    ///     }
    ///
    /// - note: `SessionsMiddleware` must be added and enabled.
    /// - returns: `Session` for this `Request`.
    public var session: Session {
        if !self._sessionCache.middlewareFlag.withLockedValue({ $0 }) {
            // No `SessionsMiddleware` was detected on your app.
            // Suggested solutions:
            // - Add the `SessionsMiddleware` globally to your app using `app.middleware.use`
            // - Add the `SessionsMiddleware` to a route group.
            assertionFailure("No `SessionsMiddleware` detected.")
        }
        if let existing = self._sessionCache.session.withLockedValue({ $0 }) {
            return existing
        } else {
            let new = Session()
            self._sessionCache.session.withLockedValue { $0 = new }
            return new
        }
    }
    
    public var hasSession: Bool {
        return self._sessionCache.session.withLockedValue { $0 != nil }
    }

    private struct SessionCacheKey: StorageKey, Sendable {
        typealias Value = SessionCache
    }
    
    internal var _sessionCache: SessionCache {
        if let existing = self.storage[SessionCacheKey.self] {
            return existing
        } else {
            let new = SessionCache()
            self.storage[SessionCacheKey.self] = new
            return new
        }
    }
}
