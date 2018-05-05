/// Uses HTTP cookies to save and restore sessions for connecting clients.
///
/// If a cookie matching the configured cookie name is found on an incoming request,
/// the value will be used as an identifier to find the associated `Session`.
///
/// If a session is used during a request (`Request.session()`), a cookie will be set
/// on the outgoing response with the session's unique identifier. This cookie must be
/// returned on the next request to restore the session.
///
///     var middlewareConfig = MiddlewareConfig()
///     middlewareConfig.use(SessionsMiddleware.self)
///     services.register(middlewareConfig)
///
/// See `SessionsConfig` and `Sessions` for more information.
public final class SessionsMiddleware: Middleware, ServiceType {
    /// See `ServiceType`.
    public static func makeService(for container: Container) throws -> SessionsMiddleware {
        return try .init(sessions: container.make(), config: container.make())
    }

    /// The cookie to work with
    let config: SessionsConfig

    /// Session store.
    public let sessions: Sessions

    /// Creates a new `SessionsMiddleware`.
    ///
    /// - parameters:
    ///     - sessions: `Sessions` implementation to use for fetching and storing sessions.
    ///     - config: `SessionsConfig` to use for naming and creating cookie values.
    public init(sessions: Sessions, config: SessionsConfig) {
        self.sessions = sessions
        self.config = config
    }

    /// See `Middleware.respond`
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        // Create a session cache
        let cache = try req.privateContainer.make(SessionCache.self)
        cache.middlewareFlag = true

        // Check for an existing session
        if let cookieValue = req.http.cookies[config.cookieName] {
            // A cookie value exists, get the session for it.
            return try sessions.readSession(sessionID: cookieValue.string).flatMap { session in
                cache.session = session
                return try next.respond(to: req).flatMap { res in
                    return try self.addCookies(to: res, for: req, cache: cache)
                }
            }
        } else {
            // No cookie value exists, simply respond.
            return try next.respond(to: req).flatMap { res in
                return try self.addCookies(to: res, for: req, cache: cache)
            }
        }
    }

    /// Adds session cookie to response or clears if session was deleted.
    private func addCookies(to res: Response, for req: Request, cache: SessionCache) throws -> Future<Response> {
        if let session = cache.session {
            // A session exists or has been created. we must
            // set a cookie value on the response
            let createOrUpdate: Future<Void>
            if session.id == nil {
                // No cookie, this is a new session.
                createOrUpdate = try sessions.createSession(session)
            } else {
                // A cookie exists, just update this session.
                createOrUpdate = try sessions.updateSession(session)
            }

            // After create or update, set cookie on the response.
            return createOrUpdate.map {
                if let id = session.id {
                    // the session has an id, set the cookie
                    res.http.cookies[self.config.cookieName] = self.config.cookieFactory(id)
                } else {
                    // the sessions has no id, expire any existing cookie
                    res.http.cookies[self.config.cookieName] = .expired
                }
                return res
            }
        } else if let cookieValue = req.http.cookies[self.config.cookieName] {
            // The request had a session cookie, but now there is no session.
            // we need to perform cleanup.
            return try self.sessions.destroySession(sessionID: cookieValue.string).map {
                res.http.cookies[self.config.cookieName] = .expired
                return res
            }
        } else {
            // no session or existing cookie
            return req.eventLoop.newSucceededFuture(result: res)
        }
    }
}
