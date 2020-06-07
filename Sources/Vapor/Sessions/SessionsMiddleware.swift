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
    let configuration: SessionsConfiguration

    /// Session store.
    public let session: SessionDriver

    /// Creates a new `SessionsMiddleware`.
    ///
    /// - parameters:
    ///     - sessions: `Sessions` implementation to use for fetching and storing sessions.
    ///     - configuration: `SessionsConfiguration` to use for naming and creating cookie values.
    public init(
        session: SessionDriver,
        configuration: SessionsConfiguration = .default()
    ) {
        self.session = session
        self.configuration = configuration
    }

    /// See `Middleware.respond`
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Signal middleware has been added.
        request._sessionCache.middlewareFlag = true

        // Check for an existing session
        if let cookieValue = request.cookies[self.configuration.cookieName] {
            // A cookie value exists, get the session for it.
            let id = SessionID(string: cookieValue.string)
            return self.session.readSession(id, for: request).flatMap { session in
                if let session = session {
                    // Session found, restore data and id.
                    request._sessionCache.session = .init(id: id, data: session)
                } else {
                    // Session id not found, create new session.
                    request._sessionCache.session = .init(data: .init(expiration: Date(timeIntervalSinceNow: self.configuration.lifetime)))
                }
                return next.respond(to: request).flatMap { res in
                    return self.addCookies(to: res, for: request)
                }
            }
        } else {
            // No cookie value exists, simply respond.
            return next.respond(to: request).flatMap { response in
                return self.addCookies(to: response, for: request)
            }
        }
    }

    /// Adds session cookie to response or clears if session was deleted.
    private func addCookies(to response: Response, for request: Request) -> EventLoopFuture<Response> {
        // If there's no session, continue immediately
        guard let session = request._sessionCache.session else {
            return request.eventLoop.makeSucceededFuture(response)
        }
        
        let interval = Date().timeIntervalSinceReferenceDate.distance(to: session.data.expiration.timeIntervalSinceReferenceDate)
        // If the session's expiration time is before this moment invalidate the session
        if interval < 0 {  session.isValid = false }
        // ... or set the cookie expiration if we're past the time to update
        // threshold, or this is a new session
        else if interval < configuration.threshold || session.id == nil {
            session.data.expiration = Date(timeIntervalSinceNow: configuration.lifetime)
        }

        // If the session is valid and nothing has updated, respond now
        if session.isValid && !session.data.anyUpdated {
            return request.eventLoop.makeSucceededFuture(response)
        }
        
        if session.isValid {
            let updatedExpiration = session.data.expiryChanged
            session.data.resetFlags()
            let createOrUpdate: EventLoopFuture<SessionID>
            if let id = session.id {
                // Session is an existing one and something was updated
                createOrUpdate = self.session.updateSession(id, to: session.data, for: request)
            } else {
                // No cookie, this is a new session.
                createOrUpdate = self.session.createSession(session.data, for: request)
            }
            
            return createOrUpdate.map { id in
                if updatedExpiration {
                    response.cookies[self.configuration.cookieName] = self.configuration.cookieFactory(id) }
                return response
            }
        } else {
            // The request had a session cookie, but now there is no valid session.
            // we need to perform cleanup.
            let cookieValue = request.cookies[self.configuration.cookieName]!
            let id = SessionID(string: cookieValue.string)
            return self.session.deleteSession(id, for: request).map {
                response.cookies[self.configuration.cookieName] = .expired
                return response
            }
        }        
    }
}
