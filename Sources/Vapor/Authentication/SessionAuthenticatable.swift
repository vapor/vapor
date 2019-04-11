/// Models conforming to this protocol can have their authentication
/// status cached using `AuthenticationSessionsMiddleware`.
public protocol SessionAuthenticatable: Authenticatable {
    /// Session identifier type.
    associatedtype SessionID: LosslessStringConvertible

    /// Unique session identifier.
    var sessionID: SessionID? { get }

    /// Authenticate a model with the supplied ID.
    static func authenticate(sessionID: SessionID) -> EventLoopFuture<Self?>
}

private extension SessionAuthenticatable {
    static var sessionName: String {
        return "\(Self.self)"
    }
}

extension Request {
    /// Authenticates the model into the session.
    public func authenticateSession<A>(_ a: A) throws where A: SessionAuthenticatable {
        try session().data["_" + A.sessionName + "Session"] = a.sessionID?.description
        self.authenticate(a)
    }

    /// Un-authenticates the model from the session.
    public func unauthenticateSession<A>(_ a: A.Type) throws where A: SessionAuthenticatable {
        guard self.hasSession else {
            return
        }
        try self.session().data["_" + A.sessionName + "Session"] = nil
        self.unauthenticate(A.self)
    }

    /// Returns the authenticatable type's ID if it exists
    /// in the session data.
    public func authenticatedSession<A>(_ a: A.Type) throws -> A.SessionID? where A: SessionAuthenticatable {
        return try session().data["_" + A.sessionName + "Session"].flatMap { A.SessionID.init($0) }
    }
}
