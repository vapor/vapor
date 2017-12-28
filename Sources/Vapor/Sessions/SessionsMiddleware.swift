/// Checks the cookies for each `Request`
public final class SessionsMiddleware<S>: Middleware where S: Sessions {
    /// The cookie to work with
    let cookieName: String
    
    /// Creates new cookies
    public let sessions: S
    
    /// Creates a new `SessionCookieMiddleware` that can validate `Request`s
    public init(cookie: String, sessions: S) {
        self.cookieName = cookie
        self.sessions = sessions
    }
    
    /// See `Middleware.respond`
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        /// create a session cache
        let cache = try request.privateContainer.make(SessionCache.self, for: SessionsMiddleware<S>.self)

        /// check for an existing session
        if let cookieValue = request.http.cookies[cookieName] {
            cache.session = try sessions.readSession(for: cookieValue)
        }

        /// generate a response for the request
        return try next.respond(to: request).map(to: Response.self) { res in
            if let session = cache.session {
                /// a session exists or has been created. we must
                /// set a cookie value on the response
                res.http.cookies[self.cookieName] = try self.sessions.updateSession(session)
            } else if let cookieValue = request.http.cookies[self.cookieName] {
                /// the request had a session cookie, but now there is no session.
                /// we need to perform cleanup.
                try self.sessions.destroySession(for: cookieValue)
            }

            return res
        }
    }
}

/// MARK: Request

extension Request {
    /// Returns the current session or creates one. `nil` if no session exists.
    public func session() throws -> Session {
        let cache = try privateContainer.make(SessionCache.self, for: Request.self)
        return cache.session ?? Session()
    }

    /// Destroys the current session, if one exists.
    public func destroySession() throws {
        let cache = try privateContainer.make(SessionCache.self, for: Request.self)
        cache.session = nil
    }
}

/// MARK: Service

internal final class SessionCache {
    var session: Session?
}
