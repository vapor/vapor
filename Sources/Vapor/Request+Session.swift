import HTTP

extension SessionCookie {
    /// Extracts a `SessionCookie` from this `Request`.
    ///
    /// Requires the `SessionCookie` to be set by `SessionCookieMiddleware`
    public init(from request: Request, named cookieName: String? = nil) throws {
        let extendToken: String
        
        // No cookieName means attempting to use the last set cookie
        if let cookieName = cookieName {
            extendToken = "vapor:session-cookie:\(cookieName)"
        } else {
            extendToken = "vapor:last-session-cookie"
        }
        
        guard let session = request.extend[extendToken] as? Self else {
            throw Error(identifier: "session-cookie:not-found", reason: "The session cookie of the type '\(Self.self)' was not found at the key '\(extendToken)' in this Request")
        }
        
        self = session
    }
}
