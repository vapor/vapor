extension Request {
    /// Returns the current `Session` or creates one.
    ///
    ///     router.get("session") { req -> String in
    ///         let session = try req.session()
    ///         session["name"] = "Vapor"
    ///         return "Session set"
    ///     }
    ///
    /// - note: `SessionsMiddleware` must be added and enabled.
    /// - returns: `Session` for this `Request`.
    public var session: Session {
        if !self._sessionCache.middlewareFlag {
            // No `SessionsMiddleware` was detected on your app.
            // Suggested solutions:
            // - Add the `SessionsMiddleware` globally to your app using `MiddlewareConfig`
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

    /// Destroys the current session, if one exists.
    public func destroySession() {
        self._sessionCache.session = nil
    }
    
    internal var _sessionCache: SessionCache {
        get {
            if let existing = self.userInfo[_sessionCacheKey] as? SessionCache {
                return existing
            } else {
                let new = SessionCache()
                self.userInfo[_sessionCacheKey] = new
                return new
            }
        }
        set {
            self.userInfo[_sessionCacheKey] = newValue
        }
    }
}

private let _sessionCacheKey = "session"
