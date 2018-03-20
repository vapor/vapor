/// Capable of managing CRUD operations for `Session`s.
public protocol Sessions: Service {
    /// Fetches a session for the supplied cookie value.
    func readSession(sessionID: String) throws -> Future<Session?>

    /// Updates the session. Call before the response
    /// with the session cookie is returned.
    func updateSession(_ session: Session) throws -> Future<Session>

    /// Destroys the session. Call if the response is no
    /// longer valid.
    func destroySession(sessionID: String) throws -> Future<Void>
}

