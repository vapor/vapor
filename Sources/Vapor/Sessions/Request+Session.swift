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
    @available(*, deprecated, message: "To ensure thread safety, migrate to `asyncSession()`")
    public var session: Session {
        if !self._sessionCache.middlewareFlag {
            // No `SessionsMiddleware` was detected on your app.
            // Suggested solutions:
            // - Add the `SessionsMiddleware` globally to your app using `app.middleware.use`
            // - Add the `SessionsMiddleware` to a route group.
            assertionFailure("No `SessionsMiddleware` detected.")
        }
        if let existing = self._sessionCache.session {
            return existing
        } else {
            let new = Session()
            self._sessionCache.session = new
            return new
        }
    }
    
    #warning("Introduce AsyncSession as a thread safe actor")
    public func asyncSession() async -> Session {
        if !self._sessionCache.middlewareFlag {
            // No `SessionsMiddleware` was detected on your app.
            // Suggested solutions:
            // - Add the `SessionsMiddleware` globally to your app using `app.middleware.use`
            // - Add the `SessionsMiddleware` to a route group.
            assertionFailure("No `SessionsMiddleware` detected.")
        }
        if let existing = self._sessionCache.session {
            return existing
        } else {
            let new = Session()
            self._sessionCache.session = new
            return new
        }
    }
    
    public var hasSession: Bool {
        return self._sessionCache.session != nil
    }

    private struct SessionCacheKey: StorageKey {
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
    
    internal func getSessionCache() async -> SessionCache {
        if let existing = await self.asyncStorage.get(SessionCacheKey.self) {
            return existing
        } else {
            let new = SessionCache()
            await self.asyncStorage.set(SessionCacheKey.self, to: new)
            return new
        }
    }
}
