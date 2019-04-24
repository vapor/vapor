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
public final class SessionsMiddleware: Middleware {
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
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Create a session cache
        let cache = SessionCache()
        request._sessionCache = cache
        cache.middlewareFlag = true

        // Check for an existing session
        if let cookieValue = request.cookies[config.cookieName] {
            // A cookie value exists, get the session for it.
            let id = SessionID(string: cookieValue.string)
            return sessions.readSession(id).flatMap { data in
                cache.session = .init(id: id, data: data ?? .init())
                return next.respond(to: request).flatMap { res in
                    return self.addCookies(to: res, for: request, cache: cache)
                }
            }
        } else {
            // No cookie value exists, simply respond.
            return next.respond(to: request).flatMap { response in
                return self.addCookies(to: response, for: request, cache: cache)
            }
        }
    }

    /// Adds session cookie to response or clears if session was deleted.
    private func addCookies(to response: Response, for request: Request, cache: SessionCache) -> EventLoopFuture<Response> {
        if let session = cache.session {
            // A session exists or has been created. we must
            // set a cookie value on the response
            let createOrUpdate: EventLoopFuture<SessionID>
            if let id = session.id {
                // A cookie exists, just update this session.
                createOrUpdate = sessions.updateSession(id, to: session.data)
            } else {
                // No cookie, this is a new session.
                createOrUpdate = sessions.createSession(session.data)
            }

            // After create or update, set cookie on the response.
            return createOrUpdate.map { id in
                // the session has an id, set the cookie
                response.cookies[self.config.cookieName] = self.config.cookieFactory(id)
                return response
            }
        } else if let cookieValue = request.cookies[self.config.cookieName] {
            // The request had a session cookie, but now there is no session.
            // we need to perform cleanup.
            let id = SessionID(string: cookieValue.string)
            return self.sessions.deleteSession(id).map {
                response.cookies[self.config.cookieName] = .expired
                return response
            }
        } else {
            // no session or existing cookie
            return self.sessions.eventLoop.makeSucceededFuture(response)
        }
    }
}
