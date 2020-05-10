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
                    request._sessionCache.session = .init(id: id, data: session.0, expiration: session.1)
                } else {
                    // Session id not found, create new session.
                    request._sessionCache.session = .init(data: .init())
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
        // Update expiration time of cookie if necessary, and invalidate if it's expired
        if let session = request._sessionCache.session {
            var newExpire: Date? = nil
            if let expiration = session.expiration {
                // If we're past expiration time - invalidate session
                if (Date().distance(to: expiration)) <= 0.0 { session.isValid = false; }
                // ... or time to expiration is less than the threshold - refresh
                else if (Date().distance(to: expiration)) < configuration.threshold {
                    newExpire = Date(timeIntervalSinceNow: configuration.lifetime)
                }
                // Otherwise we're still before the expiration threshold - nothing needs to happen
                else {
                    newExpire = nil
                }
            } else if session.expiration == nil {
                // No expiration was set (new session) - create one
                newExpire = Date(timeIntervalSinceNow: configuration.lifetime)
            }

            if session.isValid {
                let createOrUpdate: EventLoopFuture<SessionID>
                if let id = session.id, session.data.update {
                    // Session is an existing one and either data or expiration was updated
                    // Optionals for data and expiry if they need to be updated, nil otherwise
                    let data = session.data.update ? session.data : nil
                    createOrUpdate = self.session.updateSession(id, to: data, expiring: newExpire, for: request)
                } else if session.id == nil {
                    // No cookie, this is a new session.
                    createOrUpdate = self.session.createSession(session.data, expiring: newExpire!, for: request)
                } else {
                    // Session is existing but no changes happened and expiration is still valid
                    // We can just return the response directly
                    return request.eventLoop.makeSucceededFuture(response)
                }

                return createOrUpdate.map { id in
                    // Only Set-Cookie to a new one when the session is new or if TTU has passed
                    if newExpire != nil {
                        response.cookies[self.configuration.cookieName] = self.configuration.cookieFactory(id)
                    }
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
        // There's no session.
        return request.eventLoop.makeSucceededFuture(response)
    }
    
    private func updateExpiration(for sess: Session) -> Date? {
        if let expiration = sess.expiration {
            // We're past expiration time - invalidate session
            if Date() > expiration { sess.isValid = false; return nil }
            // We're still before the expiration threshold - nothing needs to happen
            if expiration - configuration.threshold > Date() { return nil }
            
            // No expiration was set (new session) or we're past the threshold - refresh it
            return Date(timeIntervalSinceNow: configuration.lifetime)
        } else {
            // No expiration was set (new session) or we're past the threshold - refresh it
            return Date(timeIntervalSinceNow: configuration.lifetime)
        }
        
    }
}
