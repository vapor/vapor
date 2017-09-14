import Foundation

/// A single Key-Value pair
public struct Cookie {
    /// The cookie's `Key`/name
    public var name: String
    
    /// The cookie's `Value` contains the value and parameters
    public var value: Value
    
    /// Creates a new Cookie
    public init(named name: String, value: Value) {
        self.name = name
        self.value = value
    }
}

extension Cookie {
    /// The `Cookie` pair's `Value`
    public struct Value: ExpressibleByStringLiteral {
        /// A cookie which can only be sent in requests originating from the same origin as the target domain.
        ///
        /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
        public enum SameSite: String {
            case strict = "Strict"
            case lax = "Lax"
        }
        
        /// The `Cookie`'s associated value
        public var value: String
        
        /// The `Cookie`'s expiration date
        public var expires: Date?
        
        /// The maximum `Cookie` age in seconds
        public var maxAge: Int?
        
        /// The affected domain at which the `Cookie` is active
        public var domain: String?
        
        /// The path at which the `Cookie` is active
        public var path: String?
        
        /// Limits the `Cookie` to secure connections
        public var secure: Bool = false
        
        /// Does not expose the `Cookie` over non-HTTP channels
        public var httpOnly: Bool = false
        
        /// A cookie which can only be sent in requests originating from the same origin as the target domain.
        ///
        /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
        public var sameSite: SameSite?
        
        /// Creates a value-only (no attributes) value
        public init(stringLiteral value: String) {
            self.value = value
        }
        
        /// Creates a new `Cookie` value
        public init(
            value: String,
            expires: Date? = nil,
            maxAge: Int? = nil,
            domain: String? = nil,
            path: String? = "/",
            secure: Bool = false,
            httpOnly: Bool = false,
            sameSite: SameSite? = nil
        ) {
            self.value = value
            self.expires = expires
            self.maxAge = maxAge
            self.domain = domain
            self.path = path
            self.secure = secure
            self.httpOnly = httpOnly
            self.sameSite = sameSite
        }
    }
}
