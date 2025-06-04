import Foundation
import HTTPTypes

extension HTTPFields {
    /// Get and set ``HTTPCookies`` for an HTTP request.
    ///
    /// This accesses the `"Cookie"` header.
    public var cookie: HTTPCookies? {
        get {
            HTTPCookies(directives: self.parseFlattenDirectives(name: .cookie))
        }
        set {
            if let cookieHeader = newValue?.cookieHeader {
                self[.cookie] = cookieHeader
            } else {
                self[.cookie] = nil
            }
        }
    }
    
    /// Get and set ``HTTPCookies`` for an HTTP response.
    ///
    /// This accesses the `"Set-Cookie"` header.
    public var setCookie: HTTPCookies? {
        get {
            let setCookies: [HTTPSetCookie] = self.parseDirectives(name: .setCookie).compactMap {
                HTTPSetCookie(directives: $0)
            }
            guard !setCookies.isEmpty else {
                return nil
            }
            var cookies = HTTPCookies()
            setCookies.forEach { cookie in
                cookies[cookie.name] = cookie.value
            }
            return cookies
        }
        set {
            self[.setCookie] = nil
            if let cookies = newValue {
                for cookieHeader in cookies.setCookieHeaders {
                    self.append(.init(name: .setCookie, value: cookieHeader))
                }
            }
        }
    }
}

struct HTTPSetCookie {
    var name: String
    var value: HTTPCookies.Value
    
    init?(directives: [HTTPFields.Directive]) {
        guard let name = directives.first, let value = name.parameter else {
            return nil
        }
        self.name = .init(name.value)
        self.value = .init(string: .init(value))
        
        for directive in directives[1...] {
            switch directive.value.lowercased() {
            case "domain":
                guard let parameter = directive.parameter else {
                    return nil
                }
                self.value.domain = .init(parameter)
            case "path":
                guard let parameter = directive.parameter else {
                    return nil
                }
                self.value.path = .init(parameter)
            case "expires":
                guard let parameter = directive.parameter else {
                    return nil
                }
                self.value.expires = Date(rfc1123: .init(parameter))
            case "httponly":
                self.value.isHTTPOnly = true
            case "secure":
                self.value.isSecure = true
            case "max-age":
                guard let parameter = directive.parameter else {
                    return nil
                }
                self.value.maxAge = Int(parameter) ?? 0
            case "samesite":
                guard let parameter = directive.parameter else {
                    return nil
                }
                self.value.sameSite = HTTPCookies.SameSitePolicy(rawValue: .init(parameter))
            default:
                return nil
            }
        }
    }
}

/// A collection of `HTTPCookie`s.
public struct HTTPCookies: ExpressibleByDictionaryLiteral, Sendable {
    /// A cookie which can only be sent in requests originating from the same origin as the target domain.
    ///
    /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
    public enum SameSitePolicy: String, Sendable {
        /// Strict mode.
        case strict = "Strict"
        /// Relaxed mode.
        case lax = "Lax"
        // Cookies marked SameSite=None should also be marked Secure.
        case none = "None"
    }
    
    /// A single cookie (key/value pair).
    public struct Value: ExpressibleByStringLiteral, Sendable {
        // MARK: Static
        
        /// An expired ``HTTPCookies/Value``.
        public static let expired: Value = .init(string: "", expires: Date(timeIntervalSince1970: 0))
        
        // MARK: Properties
        
        /// The cookie's value.
        public var string: String
        
        /// The cookie's expiration date
        public var expires: Date?
        
        /// The maximum cookie age in seconds.
        public var maxAge: Int?
        
        /// The affected domain at which the cookie is active.
        public var domain: String?
        
        /// The path at which the cookie is active.
        public var path: String?
        
        /// Limits the cookie to secure connections.
        public var isSecure: Bool
        
        /// Does not expose the cookie over non-HTTP channels.
        public var isHTTPOnly: Bool
        
        /// A cookie which can only be sent in requests originating from the same origin as the target domain.
        ///
        /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
        public var sameSite: SameSitePolicy?
        
        // MARK: Init
        
        /// Creates a new `HTTPCookieValue`.
        ///
        ///     let cookie = HTTPCookieValue(string: "123")
        ///
        /// - parameters:
        ///     - value: Value for this cookie.
        ///     - expires: The cookie's expiration date. Defaults to `nil`.
        ///     - maxAge: The maximum cookie age in seconds. Defaults to `nil`.
        ///     - domain: The affected domain at which the cookie is active. Defaults to `nil`.
        ///     - path: The path at which the cookie is active. Defaults to `"/"`.
        ///     - isSecure: Limits the cookie to secure connections. If `sameSite` is `none`, this flag will be overridden with `true`. Defaults to `false`.
        ///     - isHTTPOnly: Does not expose the cookie over non-HTTP channels. Defaults to `false`.
        ///     - sameSite: See `HTTPSameSitePolicy`. Defaults to `lax`.
        public init(
            string: String,
            expires: Date? = nil,
            maxAge: Int? = nil,
            domain: String? = nil,
            path: String? = "/",
            isSecure: Bool = false,
            isHTTPOnly: Bool = false,
            sameSite: SameSitePolicy? = .lax
        ) {
            self.string = string
            self.expires = expires
            self.maxAge = maxAge
            self.domain = domain
            self.path = path
            // SameSite=None requires Secure attribute to be set
            // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite
            let forceSecure = sameSite == SameSitePolicy.none
            self.isSecure = isSecure || forceSecure
            self.isHTTPOnly = isHTTPOnly
            self.sameSite = sameSite
        }
        
        // See `ExpressibleByStringLiteral.init(stringLiteral:)`.
        public init(stringLiteral value: String) {
            self.init(string: value)
        }
        
        // MARK: Methods
        
        /// Serializes an `HTTPCookie` to a `String`.
        public func serialize(name: String) -> String {
            var serialized = "\(name)=\(self.string)"
            
            if let expires = self.expires {
                serialized += "; Expires=\(expires.rfc1123)"
            }
            
            if let maxAge = self.maxAge {
                serialized += "; Max-Age=\(maxAge)"
            }
            
            if let domain = self.domain {
                serialized += "; Domain=\(domain)"
            }
            
            if let path = self.path {
                serialized += "; Path=\(path)"
            }
            
            if self.isSecure {
                serialized += "; Secure"
            }
            
            if self.isHTTPOnly {
                serialized += "; HttpOnly"
            }
            
            if let sameSite = self.sameSite {
                serialized += "; SameSite"
                switch sameSite {
                case .lax:
                    serialized += "=Lax"
                case .strict:
                    serialized += "=Strict"
                case .none:
                    serialized += "=None"
                }
            }
            
            return serialized
        }
    }
    
    /// Internal storage.
    private var cookies: [String: Value]
    
    /// Creates an empty ``HTTPCookies``.
    public init() {
        self.cookies = [:]
    }
    
    init(directives: [HTTPFields.Directive]) {
        self.cookies = directives.reduce(into: [:], { (cookies, directive) in
            if let value = directive.parameter {
                cookies[.init(directive.value)] = .init(string: .init(value))
            }
        })
    }
    
    // See `ExpressibleByDictionaryLiteral.init(dictionaryLiteral:)`.
    public init(dictionaryLiteral elements: (String, Value)...) {
        var cookies: [String: Value] = [:]
        for (name, value) in elements {
            cookies[name] = value
        }
        self.cookies = cookies
    }
    
    // MARK: Serialize
    
    /// Serializes the ``HTTPCookies`` for a ``Request``.
    var cookieHeader: String? {
        guard !self.cookies.isEmpty else {
            return nil
        }
        
        let cookie: String = self.cookies.map { (name, value) in
            return "\(name)=\(value.string)"
        }.joined(separator: "; ")
        
        return cookie
    }
    
    var setCookieHeaders: [String] {
        return self.cookies.map { $0.value.serialize(name: $0.key) }
    }
    
    // MARK: Access
    
    /// All cookies.
    public var all: [String: Value] {
        get { return self.cookies }
        set { self.cookies = newValue }
    }
    
    /// Access ``HTTPCookies`` by name
    public subscript(name: String) -> Value? {
        get { return self.cookies[name] }
        set { self.cookies[name] = newValue }
    }
}
