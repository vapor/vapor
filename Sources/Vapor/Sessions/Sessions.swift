/// Capable of managing CRUD operations for `Session`s.
public protocol Sessions {
    /// Generates a new session.
    func createSession() throws -> Session

    /// Fetches a session for the supplied cookie value.
    func readSession(for cookie: Cookie.Value) throws -> Session

    /// Updates the session. Call before the response
    /// with the session cookie is returned.
    func updateSession(_ session: Session) throws

    /// Destroys the session. Call if the response is no
    /// longer valid.
    func destroySession(_ session: Session) throws
}
