import Synchronization

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
        // Checking the flag and creating the session share one lock: two separate locks meant the
        // check and the create could not be relied on to see the same state.
        return self.sessionCache.storage.withLock { storage in
            if !storage.middlewareFlag {
                // No `SessionsMiddleware` was detected on your app.
                // Suggested solutions:
                // - Add the `SessionsMiddleware` globally to your app using `app.middleware.use`
                // - Add the `SessionsMiddleware` to a route group.
                assertionFailure("No `SessionsMiddleware` detected.")
            }
            if let existing = storage.session {
                return existing
            }
            let new = Session()
            storage.session = new
            return new
        }
    }

    public var hasSession: Bool {
        self.sessionCache.storage.withLock { $0.session != nil }
    }
}
