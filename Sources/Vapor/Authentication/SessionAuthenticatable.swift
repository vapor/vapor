/// Helper for creating authentication middleware in conjunction with `SessionsMiddleware`.
public protocol SessionAuthenticator: Authenticator {
    associatedtype User: SessionAuthenticatable

    /// Authenticate a model with the supplied ID.
    func authenticate(sessionID: User.SessionID, for request: Request) -> EventLoopFuture<Void>
}

extension SessionAuthenticator {
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let promise = request.eventLoop.makePromise(of: Response.self)
        promise.completeWithTask {
            // if the user has already been authenticated
            // by a previous middleware, continue
            if await request.auth.has(User.self) {
                return try await next.respond(to: request).get()
            }

            if let aID = await request.asyncSession().authenticated(User.self) {
                // try to find user with id from session
                try await self.authenticate(sessionID: aID, for: request).get()
            }

            // respond to the request
            let response = try await next.respond(to: request).get()
            if let user = await request.auth.get(User.self) {
                // if a user has been authed (or is still authed), store in the session
                await request.asyncSession().authenticate(user)
            } else if await request.hasAsyncSession {
                // if no user is authed, it's possible they've been unauthed.
                // remove from session.
                await request.asyncSession().unauthenticate(User.self)
            }
            return response
        }
        return promise.futureResult
    }
}

/// Models conforming to this protocol can have their authentication
/// status cached using `SessionAuthenticator`.
public protocol SessionAuthenticatable: Authenticatable {
    /// Session identifier type.
    associatedtype SessionID: LosslessStringConvertible

    /// Unique session identifier.
    var sessionID: SessionID { get }
}

private extension SessionAuthenticatable {
    static var sessionName: String {
        return "\(Self.self)"
    }
}

@available(*, deprecated, message: "Migrate to the async session APIs")
extension Session {
    /// Authenticates the model into the session.
    public func authenticate<A>(_ a: A)
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"] = a.sessionID.description
    }

    /// Un-authenticates the model from the session.
    public func unauthenticate<A>(_ a: A.Type)
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"] = nil
    }

    /// Returns the authenticatable type's ID if it exists
    /// in the session data.
    public func authenticated<A>(_ a: A.Type) -> A.SessionID?
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"]
            .flatMap { A.SessionID.init($0) }
    }
}

#if canImport(_Concurrency)
extension Session {
    /// Authenticates the model into the session.
    public func authenticate<A>(_ a: A) async
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"] = a.sessionID.description
    }

    /// Un-authenticates the model from the session.
    public func unauthenticate<A>(_ a: A.Type) async
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"] = nil
    }

    /// Returns the authenticatable type's ID if it exists
    /// in the session data.
    public func authenticated<A>(_ a: A.Type) async -> A.SessionID?
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"]
            .flatMap { A.SessionID.init($0) }
    }
}
#endif
