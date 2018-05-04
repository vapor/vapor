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
        let cache = try privateContainer.make(SessionCache.self)
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

    /// Destroys the current session, if one exists.
    public func destroySession() throws {
        let cache = try privateContainer.make(SessionCache.self)
        cache.session = nil
    }
}
