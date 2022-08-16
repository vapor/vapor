/// Uses HTTP cookies to save and restore sessions for connecting clients.
///
/// If a cookie matching the configured cookie name is found on an incoming request,
/// the value will be used as an identifier to find the associated `Session`.
///
/// If a session is used during a request (`Request.session()`), a cookie will be set
/// on the outgoing response with the session's unique identifier. This cookie must be
/// returned on the next request to restore the session.
///
///     app.middleware.use(app.sessions.middleware)
///
/// See `SessionsConfig` and `Sessions` for more information.
public final class SessionsMiddleware: AsyncMiddleware {
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
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Signal middleware has been added.
        // This is here to ensure that anyone who hasn't migrated doesn't start getting errors
        request._legacySessionCache.middlewareFlag = true
        await request._asyncSessionCache.middlewareFlag = true

        // Check for an existing session
        if let cookieValue = request.cookies[self.configuration.cookieName] {
            // A cookie value exists, get the session for it.
            let id = SessionID(string: cookieValue.string)
            let data = try await self.session.readSession(id, for: request).get()
            if let data = data {
                // Session found, restore data and id.
                request._legacySessionCache.session = .init(id: id, data: data)
                await request._asyncSessionCache.session = .init(id: id, data: data)
            } else {
                // Session id not found, create new session.
                request._legacySessionCache.session = .init()
                await request._asyncSessionCache.session = .init()
            }
        }
        
        let response = try await next.respond(to: request)
        return try await self.addCookies(to: response, for: request)
    }

    /// Adds session cookie to response or clears if session was deleted.
    private func addCookies(to response: Response, for request: Request) async throws -> Response {
        // Test new session first
        if let session = await request._asyncSessionCache.session, session.isValid {
            // Copy any data from old session to new session
            if let oldSession = request._legacySessionCache.session {
                for (key, value) in oldSession.data.snapshot {
                    session.data[key] = value
                }
            }
            try await createOrUpdateSessionCookie(session: session, for: request, to: response)
        } else if let cookieValue = request.cookies[self.configuration.cookieName] {
            // The request had a session cookie, but now there is no valid session.
            // we need to perform cleanup.
            let id = SessionID(string: cookieValue.string)
            try await self.session.deleteSession(id, for: request).get()
            response.cookies[self.configuration.cookieName] = .expired
        }
        return response
    }
    
    private func createOrUpdateSessionCookie(session: Session, for request: Request, to response: Response) async throws {
        // A session exists or has been created. we must
        // set a cookie value on the response
        let newID: SessionID
        if let id = session.id {
            // A cookie exists, just update this session.
            newID = try await self.session.updateSession(id, to: session.data, for: request).get()
        } else {
            // No cookie, this is a new session.
            newID = try await self.session.createSession(session.data, for: request).get()
        }

        // After create or update, set cookie on the response.
        response.cookies[self.configuration.cookieName] = self.configuration.cookieFactory(newID)
    }
}
