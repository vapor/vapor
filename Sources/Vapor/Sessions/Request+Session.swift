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
    public func session() throws -> Session {
        guard let cache = self._sessionCache else {
            fatalError("No session cache.")
        }
        guard cache.middlewareFlag else {
            throw VaporError(
                identifier: "sessionsMiddlewareFlag",
                reason: "No `SessionsMiddleware` detected.",
                suggestedFixes: [
                    "Add the `SessionsMiddleware` globally to your app using `MiddlewareConfig`.",
                    "Add the `SessionsMiddleware` to a route group."
                ]
            )
        }
        if let existing = cache.session {
            return existing
        } else {
            let new = Session()
            cache.session = new
            return new
        }
    }
    
    public var hasSession: Bool {
        return self._sessionCache?.session != nil
    }

    /// Destroys the current session, if one exists.
    public func destroySession() throws {
        self._sessionCache?.session = nil
    }
    
    internal var _sessionCache: SessionCache? {
        get { return self.userInfo[_sessionCacheKey] as? SessionCache }
        set { self.userInfo[_sessionCacheKey] = newValue }
    }
}

private let _sessionCacheKey = "session"
