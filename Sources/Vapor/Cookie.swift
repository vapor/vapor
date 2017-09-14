import Foundation

/**
 Represents an HTTP Cookie as described
 in HTTP State Management Mechanism (RFC 6265)
 */
public struct Cookie {
    public var name: String
    public var value: Value
    
    public init(named name: String, value: Value) {
        self.name = name
        self.value = value
    }
}

extension Cookie {
    public struct Value: ExpressibleByStringLiteral {
        public enum SameSite: String {
            case strict
            case lax
        }
        
        public var value: String
        public var expires: Date?
        public var maxAge: Int?
        public var domain: String?
        public var path: String?
        public var secure: Bool = false
        public var httpOnly: Bool = false
        public var sameSite: SameSite?
        
        public init(stringLiteral value: String) {
            self.value = value
        }
        
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
