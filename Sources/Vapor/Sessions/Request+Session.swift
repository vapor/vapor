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
    
    public var asyncSession: AsyncSession {
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
                let new = AsyncSession()
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
    
    private struct AsyncSessionCacheKey: StorageKey {
        typealias Value = AsyncSessionCache
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
    
    internal var _asyncSessionCache: AsyncSessionCache {
        get async {
            if let existing = await self.asyncStorage.get(AsyncSessionCacheKey.self) {
                return existing
            } else {
                let new = AsyncSessionCache()
                await self.asyncStorage.set(AsyncSessionCacheKey.self, to: new)
                return new
            }
        }
    }
}
