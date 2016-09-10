import HTTP

extension Request {
    /// Server stored information related from session cookie.
    public func session() throws -> Session {
        guard let session = storage["session"] as? Session else {
            throw SessionsError.notConfigured
        }

        return session
    }
}
