extension Request {
    /// Returns the current session or creates one. `nil` if no session exists.
    public func session() throws -> Session {
        let cache = try privateContainer.make(SessionCache.self, for: Request.self)
        guard cache.middlewareFlag else {
            throw VaporError(
                identifier: "sessionsMiddlewareFlag",
                reason: "No `SessionsMiddleware` detected.",
                suggestedFixes: [
                    "Add the `SessionsMiddleware` globally to your app using `MiddlewareConfig`.",
                    "Add the `SessionsMiddleware` to a route group."
                ],
                source: .capture()
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
        let cache = try privateContainer.make(SessionCache.self, for: Request.self)
        cache.session = nil
    }
}

