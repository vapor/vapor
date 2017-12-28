/// Something that is convertible between a Cookie and an instance.
public final class Session: CookieValueInitializable, CookieValueRepresentable {
    /// The cookie value
    public let cookie: Cookie.Value

    /// This session's data
    public var data: [String: Encodable]

    /// True if the Session is still valid
    var isValid: Bool

    /// Create a new session for the cookie vlaue
    public init(from cookie: Cookie.Value) {
        self.cookie = cookie
        isValid = true
        data = [:]
    }

    /// Destroys the session, invalidating the cookie.
    public func destroy() throws {
        isValid = false
    }

    /// See CookieValueRepresentable.makeCookieValue
    public func makeCookieValue() throws -> Cookie.Value {
        return cookie
    }
}
