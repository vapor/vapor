import HTTP

private let sessionKey = "session"

extension Request {
    /// Server stored information related from session cookie.
    public func session() throws -> Session {
        guard let session = storage[sessionKey] as? Session else {
            throw SessionsError.notConfigured
        }

        return session
    }

    internal func set(_ session: Session) {
        storage[sessionKey] = session
    }
}
