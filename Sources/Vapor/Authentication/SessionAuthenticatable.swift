/// Helper for creating authentication middleware in conjunction with `SessionsMiddleware`.
public protocol SessionAuthenticator: Authenticator {
    associatedtype User: SessionAuthenticatable

    /// Authenticate a model with the supplied ID.
    func authenticate(sessionID: User.SessionID, for request: Request) -> EventLoopFuture<Void>
}

extension SessionAuthenticator {
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if request.auth.has(User.self) {
            return next.respond(to: request)
        }

        let future: EventLoopFuture<Void>
        if let aID = request.session.authenticated(User.self) {
            // try to find user with id from session
            future = self.authenticate(sessionID: aID, for: request)
        } else {
            // no need to authenticate
            future = request.eventLoop.makeSucceededFuture(())
        }

        // map the auth future to a resopnse
        return future.flatMap { _ in
            // respond to the request
            return next.respond(to: request).map { response in
                if let user = request.auth.get(User.self) {
                    // if a user has been authed (or is still authed), store in the session
                    request.session.authenticate(user)
                } else if request.hasSession {
                    // if no user is authed, it's possible they've been unauthed.
                    // remove from session.
                    request.session.unauthenticate(User.self)
                }
                return response
            }
        }
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
        return "\(Self.self)_Session"
    }
}

extension Session {
    /// Authenticates the model into the session.
    public func authenticate<A>(_ a: A)
        where A: SessionAuthenticatable
    {
        self.data.appStorage[A.sessionName] = a.sessionID.description
    }

    /// Un-authenticates the model from the session.
    public func unauthenticate<A>(_ a: A.Type)
        where A: SessionAuthenticatable
    {
        self.data.appStorage[A.sessionName] = nil
    }

    /// Returns the authenticatable type's ID if it exists
    /// in the session data.
    public func authenticated<A>(_ a: A.Type) -> A.SessionID?
        where A: SessionAuthenticatable
    {
        self.data.appStorage[A.sessionName].flatMap { A.SessionID.init($0) }
    }
}
