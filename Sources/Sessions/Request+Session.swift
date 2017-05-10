import HTTP

private let sessionKey = "sessions:session"

extension Request {
    /// Server stored information related from session cookie.
    public func assertSession() throws -> Session {
        guard let session = self.session else {
            throw SessionsError.notConfigured
        }

        return session
    }
    
    public var session: Session? {
        get { return storage[sessionKey] as? Session }
        set { storage[sessionKey] = newValue }
    }
}
