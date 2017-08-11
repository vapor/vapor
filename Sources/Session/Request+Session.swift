import HTTP

private let sessionKey = "sessions:session"

extension Request {
    /// Returns the session for this request or throws an error
    /// if sessions have not been properly configured.
    public func assertSession() throws -> Session {
        guard let session = self.session else {
            throw SessionsError.notConfigured()
        }

        return session
    }

    /// Access the session for this request. 
    public var session: Session? {
        get { return storage[sessionKey] as? Session }
        set { storage[sessionKey] = newValue }
    }
}
