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
        let session: Session

        let cookieName = self.cookieName
        if let cookieValue = request.http.cookies[cookieName] {
            session = try sessions.readSession(for: cookieValue)
        } else {
            let cookieValue = try sessions.createSession()
            session = cookieValue
        }

        let cache = try request.privateContainer.make(SessionCache.self, for: SessionsMiddleware<S>.self)
        cache.session = session

        return try next.respond(to: request).map(to: Response.self) { res in
            if session.isValid {
                res.http.cookies[cookieName] = session.cookie
                try self.sessions.updateSession(session)
            } else {
                try self.sessions.destroySession(session)
            }

            return res
        }
    }
}

/// MARK: Request

extension Request {
    /// Returns the current session. `nil` if no session exists.
    public func session() throws -> Session? {
        let cache = try privateContainer.make(SessionCache.self, for: Request.self)
        return cache.session
    }

    /// Returns the current session, throwing an error if no session exists.
    public func requireSession() throws -> Session {
        guard let session = try self.session() else {
            throw VaporError(identifier: "noSession", reason: "A session is required.")
        }

        return session
    }
}

/// MARK: Service

internal final class SessionCache {
    var session: Session?
}
