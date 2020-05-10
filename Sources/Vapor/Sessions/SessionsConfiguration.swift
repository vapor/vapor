/// Configuration options for sessions.
public struct SessionsConfiguration {
    /// Creates a new `HTTPCookieValue` for the supplied value `String`.
    public var cookieFactory: (SessionID) -> HTTPCookies.Value

    /// Name of HTTP cookie, used as a key for the cookie value.
    public var cookieName: String
    
    /// Session lifetime interval and time-to-update in seconds
    /// `lifetime == 0`, indefinite lifetime
    /// `timeToUpdate == 0`, always update
    public let lifetime: Double
    public let timeToUpdate: Double
    public let threshold: Double

    /// Create a new `SessionsConfig` with the supplied cookie factory.
    ///
    ///     let sessionsConfig = SessionsConfig(cookieName: "vapor-session") { value in
    ///         return HTTPCookieValue(string: value, isSecure: true)
    ///     }
    ///
    /// - parameters:
    ///     - cookieName: Name of HTTP cookie, used as a key for the cookie value.
    ///     - cookieLifetime: Duration in seconds of cookie lifetime - if `nil`, implicit cookie expiration
    ///         time will be used as the duration. If cookies set an expiration time, should be the same as
    ///         `maxAge`/`expires` time or with a 5 second increase to allow some variance for client-side latency.
    ///         If cookies set no expiration (ephemeral session cookies), `cookieLifetime` can be used to
    ///         enforce killing "dead" sessions
    ///     - cookieTTU: Duration in seconds of interval past when cookie expiration should be updated and re-sent
    ///         to client, to minimize update frequency (or preventing refreshed cookies at all for security). `Lifetime`
    ///         must be set to use; clamped between `0...cookieLifetime` with `0` meaning "update on
    ///         every request" and `== cookieLifetime` being never extend. Practically this value is application-
    ///         dependent and should be evaluated. EG; a 7 day expiration lifetime for a persistent cookie with a 1 day
    ///         TTU still permits at least 6 days of inactivity before the cookie expires, greatly reducing packet overhead
    ///         and backend updating of the session data store if no changes to the session data occur during a request.
    ///     - cookieFactory: Creates a new `HTTPCookieValue` for the supplied value `String`.
    public init( cookieName: String,
                 cookieLifetime: UInt? = nil,
                 cookieTTU: UInt? = nil,
                 cookieFactory: @escaping (SessionID) -> HTTPCookies.Value) {
        self.cookieName = cookieName
        self.cookieFactory = cookieFactory
        
        let sampleCookie = self.cookieFactory(SessionID(string: "test"))
        let expireAge = Int(sampleCookie.expires?.timeIntervalSinceNow ?? -1)
        let maxAge = sampleCookie.maxAge ?? -1
        let neitherSet = sampleCookie.expires == nil && sampleCookie.maxAge == nil
        
        /// Set cookie `calculatedAge` to the greatest value present
        /// Could be -1 if neither is set or is misconfigured to negative values, 0 if misconfigured, or postiive.
        let calculatedAge = max(expireAge, maxAge)
        /// Sanity checks if values between expire and maxAge are different or cookies are set to immediately expire. 1 second tick variance
        if (sampleCookie.expires != nil && sampleCookie.maxAge != nil) {
            assert(abs(expireAge-maxAge) <= 1, "Ensure consistent setting between maxAge & expires")
        }
        assert(calculatedAge > 0 || neitherSet, "Cookie factory shouldn't set immediately expiring age for sessions")
        
        /// Set lifetime to the greater of implicit cookie age or explicit lifetime, if set
        let maxLife = max(UInt(calculatedAge), cookieLifetime ?? 0)
        /// Non-expiring session cookies with no server-side expiration time set is very unwise. If it's really desirable, it should
        /// still be configured explicitly with an extremely long `cookieLifetime` since malicious clients could indefinitely
        /// persist a cookie otherwise expected by the server to be eventually expiring.
        assert(maxLife > 0,
            "Configure at least one expiration deadline either implicitly via cookie expiry or explicit configuration")
        if calculatedAge > 0, maxLife > 0 {
            /// Expiring cookies with a stated lifetime - check that we're not off by more than 5 seconds between the two
            /// or assert that we're mis-configured. 5 seconds is an arbitrary limit to allow some over-setting of
            /// `cookieLifetime` to account for latency between server-client communications.
            assert((0...5).contains(maxLife - UInt(calculatedAge)), "Ensure your cookie configuration is consistent")
        }
        
        self.lifetime = Double(maxLife)
        
        /// Ensure `cookieTTU`, if set, is valid within the range of the cookie lifetime, clamp it anyway, or set to 0 if we're not using a TTU
        if let cookieTTU = cookieTTU {
            assert(cookieTTU <= maxLife, "timeToUpdate must be <= \(maxLife)")
            self.timeToUpdate = Double(min(cookieTTU, maxLife))
        } else { self.timeToUpdate = 0 }
        
        self.threshold = self.lifetime - self.timeToUpdate
    }

    /// `SessionsConfig` with basic cookie factory.
    public static func `default`(life: UInt = 60 * 60 * 24 * 7,  // Default lifetime of 1 Week
                                 ttu: UInt? = nil)
        -> SessionsConfiguration {
            return .init(cookieName: "vapor-session", cookieLifetime: life, cookieTTU: ttu) { sessionID in
                return HTTPCookies.Value(
                    string: sessionID.string,
                    expires: Date(
                        timeIntervalSinceNow: Double(life)
                    ),
                    maxAge: nil,
                    domain: nil,
                    path: "/",
                    isSecure: false,
                    isHTTPOnly: false,
                    sameSite: nil
                )
            }
    }
}
