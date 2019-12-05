public protocol SessionAuthenticator: Authenticator
    where Self.User: SessionAuthenticatable
{
    /// Authenticate a model with the supplied ID.
    func resolve(sessionID: User.SessionID) -> EventLoopFuture<User?>
}

extension SessionAuthenticator {
    public func middleware() -> Middleware {
        return SessionAuthenticationMiddleware<Self>(authenticator: self)
    }
}

/// Models conforming to this protocol can have their authentication
/// status cached using `AuthenticationSessionsMiddleware`.
public protocol SessionAuthenticatable: Authenticatable {
    /// Session identifier type.
    associatedtype SessionID: LosslessStringConvertible

    /// Unique session identifier.
    var sessionID: SessionID? { get }
}

private extension SessionAuthenticatable {
    static var sessionName: String {
        return "\(Self.self)"
    }
}

extension Session {
    /// Authenticates the model into the session.
    public func authenticate<A>(_ a: A)
        where A: SessionAuthenticatable
    {
        self.data["_" + A.sessionName + "Session"] = a.sessionID?.description
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
        return self.data["_" + A.sessionName + "Session"]
            .flatMap { A.SessionID.init($0) }
    }
}

private final class SessionAuthenticationMiddleware<A>: Middleware
    where A: SessionAuthenticator
{
    let authenticator: A

    /// create a new password auth middleware
    public init(authenticator: A) {
        self.authenticator = authenticator
    }

    /// See Middleware.respond
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if request.auth.has(A.User.self) {
            return next.respond(to: request)
        }
        
        let future: EventLoopFuture<Void>
        if let aID = request.session.authenticated(A.User.self) {
            // try to find user with id from session
            future = self.authenticator.resolve(sessionID: aID).map { user in
                // if the user was found, auth it
                if let user = user {
                    request.auth.login(user)
                }
            }
        } else {
            // no need to authenticate
            future = request.eventLoop.makeSucceededFuture(())
        }

        // map the auth future to a resopnse
        return future.flatMap { _ in
            // respond to the request
            return next.respond(to: request).map { response in
                if let user = request.auth.get(A.User.self) {
                    // if a user has been authed (or is still authed), store in the session
                    request.session.authenticate(user)
                } else if request.hasSession {
                    // if no user is authed, it's possible they've been unauthed.
                    // remove from session.
                    request.session.unauthenticate(A.User.self)
                }
                return response
            }
        }
    }
}
