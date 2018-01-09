/// Capable of managing CRUD operations for `Session`s.
public protocol Sessions: Service {
    /// Fetches a session for the supplied cookie value.
    func readSession(for cookie: Cookie.Value) throws -> Session?

    /// Updates the session. Call before the response
    /// with the session cookie is returned.
    func updateSession(_ session: Session) throws -> Cookie.Value

    /// Destroys the session. Call if the response is no
    /// longer valid.
    func destroySession(for cookie: Cookie.Value) throws
}
