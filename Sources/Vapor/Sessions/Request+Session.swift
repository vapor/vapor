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
    @available(*, deprecated, message: "To ensure thread safety, migrate to `asyncSession`")
    public var session: Session {
        if !self._legacySessionCache.middlewareFlag {
            // No `SessionsMiddleware` was detected on your app.
            // Suggested solutions:
            // - Add the `SessionsMiddleware` globally to your app using `app.middleware.use`
            // - Add the `SessionsMiddleware` to a route group.
            assertionFailure("No `SessionsMiddleware` detected.")
        }
        if let existing = self._legacySessionCache.session {
            return existing
        } else {
            let new = Session()
            self._legacySessionCache.session = new
            return new
        }
    }
    
    #warning("Introduce AsyncSession as a thread safe actor")
    public var asyncSession: Session {
        get async {
            if await !self._asyncSessionCache.middlewareFlag {
                // No `SessionsMiddleware` was detected on your app.
                // Suggested solutions:
                // - Add the `SessionsMiddleware` globally to your app using `app.middleware.use`
                // - Add the `SessionsMiddleware` to a route group.
                assertionFailure("No `SessionsMiddleware` detected.")
            }
            if let existing = await self._asyncSessionCache.session {
                return existing
            } else {
                let new = Session()
                await self._asyncSessionCache.session = new
                return new
            }
        }
    }
    
    @available(*, deprecated, message: "To ensure thread safety, migrate to `hasAsyncSession()`")
    public var hasSession: Bool {
        return self._legacySessionCache.session != nil
    }
    
    public var hasAsyncSession: Bool {
        get async {
            let hasAsyncSession = await self._asyncSessionCache.session != nil
            return self._legacySessionCache.session != nil || hasAsyncSession
        }
    }

    private struct SessionCacheKey: StorageKey {
        typealias Value = SessionCache
    }
    
    internal var _legacySessionCache: SessionCache {
        if let existing = self.storage[SessionCacheKey.self] {
            return existing
        } else {
            let new = SessionCache()
            self.storage[SessionCacheKey.self] = new
            return new
        }
    }
    
    internal var _asyncSessionCache: SessionCache {
        get async {
            if let existing = await self.asyncStorage.get(SessionCacheKey.self) {
                return existing
            } else {
                let new = SessionCache()
                await self.asyncStorage.set(SessionCacheKey.self, to: new)
                return new
            }
        }
    }
}
