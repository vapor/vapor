import HTTP

extension Request {
    /// Extracts a `SessionCookie` from this `Request`.
    ///
    /// Requires the `SessionCookie` to be set by `SessionCookieMiddleware`
    public func sessionCookie<SC: SessionCookie>(named cookieName: String? = nil) throws -> SC {
        let extendToken: String
        
        // No cookieName means attempting to use the last set cookie
        if let cookieName = cookieName {
            extendToken = "vapor:session-cookie:\(cookieName)"
        } else {
            extendToken = "vapor:last-session-cookie"
        }
        
        guard let session = self.extend[extendToken] as? SC else {
            throw Error(identifier: "session-cookie:not-found", reason: "The session cookie of the type '\(SC.self)' was not found at the key '\(extendToken)' in this Request")
        }
        
        return session
    }
}
