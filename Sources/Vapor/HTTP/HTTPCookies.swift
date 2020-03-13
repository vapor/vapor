extension HTTPHeaders {
    /// Get and set `HTTPCookies` for an HTTP request
    /// This accesses the `"Cookie"` header.
    public var cookie: HTTPCookies {
        get {
            return self.first(name: .cookie)
                .flatMap(HTTPCookies.parse) ?? [:]
        }
        set {
            if let cookieHeader = newValue.cookieHeader {
                self.replaceOrAdd(name: .cookie, value: cookieHeader)
            } else {
                self.remove(name: .cookie)
            }
        }
    }

    /// Get and set `HTTPCookies` for an HTTP response
    /// This accesses the `"Set-Cookie"` header.
    public var setCookie: HTTPCookies {
        get {
            return HTTPCookies.parse(setCookieHeaders: self[.setCookie]) ?? [:]
        }
        set {
            self.remove(name: .setCookie)
            for cookieHeader in newValue.setCookieHeaders {
                self.add(name: .setCookie, value: cookieHeader)
            }
        }
    }
}

/// A collection of `HTTPCookie`s.
public struct HTTPCookies: ExpressibleByDictionaryLiteral {
    /// A cookie which can only be sent in requests originating from the same origin as the target domain.
    ///
    /// This restriction mitigates attacks such as cross-site request forgery (XSRF).
    public enum SameSitePolicy: String {
        /// Strict mode.
        case strict = "Strict"
        /// Relaxed mode.
        case lax = "Lax"
    }
    
    /// A single cookie (key/value pair).
    public struct Value: ExpressibleByStringLiteral {
        // MARK: Static
        
        /// An expired `HTTPCookieValue`.
        public static let expired: Value = .init(string: "", expires: Date(timeIntervalSince1970: 0))
        
        /// Parses an individual `HTTPCookie` from a `String`.
        ///
        ///     let cookie = HTTPCookie.parse("sessionID=123; HTTPOnly")
        ///
        /// - parameters:
        ///     - data: `LosslessDataConvertible` to parse the cookie from.
        /// - returns: `HTTPCookie` or `nil` if the data is invalid.
        public static func parse(_ data: String) -> (String, Value)? {
            #warning("TODO: fix")
            fatalError()
//            var parser = HTTPHeaders.ValueParser(string: data)
//            guard let (name, string) = parser.nextParameter() else {
//                return nil
//            }
//
//            /// Fetch params.
//            var expires: Date?
//            var maxAge: Int?
//            var domain: String?
//            var path: String?
//            var secure = false
//            var httpOnly = false
//            var sameSite: SameSitePolicy?
//
//            while let (key, value) = parser.nextParameter() {
//                let val = String(value)
//                switch key.lowercased() {
//                case "domain": domain = val
//                case "path": path = val
//                case "expires": expires = Date(rfc1123: val)
//                case "httponly": httpOnly = true
//                case "secure": secure = true
//                case "max-age": maxAge = Int(val) ?? 0
//                case "samesite": sameSite = SameSitePolicy(rawValue: val)
//                default: break
//                }
//            }
//
//            let value = Value(
//                string: .init(string),
//                expires: expires,
//                maxAge: maxAge,
//                domain: domain,
//                path: path,
//                isSecure: secure,
//                isHTTPOnly: httpOnly,
//                sameSite: sameSite
//            )
//            return (.init(name), value)
        }
        
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
        ///     - isSecure: Limits the cookie to secure connections. Defaults to `false`.
        ///     - isHTTPOnly: Does not expose the cookie over non-HTTP channels. Defaults to `false`.
        ///     - sameSite: See `HTTPSameSitePolicy`. Defaults to `nil`.
        public init(
            string: String,
            expires: Date? = nil,
            maxAge: Int? = nil,
            domain: String? = nil,
            path: String? = "/",
            isSecure: Bool = false,
            isHTTPOnly: Bool = false,
            sameSite: SameSitePolicy? = nil
        ) {
            self.string = string
            self.expires = expires
            self.maxAge = maxAge
            self.domain = domain
            self.path = path
            self.isSecure = isSecure
            self.isHTTPOnly = isHTTPOnly
            self.sameSite = sameSite
        }
        
        /// See `ExpressibleByStringLiteral`.
        public init(stringLiteral value: String) {
            self.init(string: value)
        }
        
        // MARK: Methods
        
        /// Seriaizes an `HTTPCookie` to a `String`.
        public func serialize(name: String) -> String {
            var serialized = "\(name)=\(string)"
            
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
            
            if isSecure {
                serialized += "; Secure"
            }
            
            if isHTTPOnly {
                serialized += "; HttpOnly"
            }
            
            if let sameSite = self.sameSite {
                serialized += "; SameSite"
                switch sameSite {
                case .lax:
                    serialized += "=Lax"
                case .strict:
                    serialized += "=Strict"
                }
            }
            
            return serialized
        }
    }
    
    /// Internal storage.
    private var cookies: [String: Value]
    
    /// Creates an empty `HTTPCookies`
    public init() {
        self.cookies = [:]
    }
    
    // MARK: Parse
    
    /// Parses a `Request` cookie
    public static func parse(cookieHeader: String) -> HTTPCookies? {
        var cookies: HTTPCookies = [:]
        
        // cookies are sent separated by semicolons
        let tokens = cookieHeader.components(separatedBy: ";")
        
        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let (name, value) = Value.parse(token) else {
                return nil
            }
            
            cookies[name] = value
        }
        
        return cookies
    }
    
    /// Parses a `Response` cookie
    public static func parse(setCookieHeaders: [String]) -> HTTPCookies? {
        var cookies: HTTPCookies = [:]
        
        for token in setCookieHeaders {
            // If a single deserialization fails, the cookies are malformed
            guard let (name, value) = Value.parse(token) else {
                return nil
            }
            
            cookies[name] = value
        }
        
        return cookies
    }
    
    /// See `ExpressibleByDictionaryLiteral`.
    public init(dictionaryLiteral elements: (String, Value)...) {
        var cookies: [String: Value] = [:]
        for (name, value) in elements {
            cookies[name] = value
        }
        self.cookies = cookies
    }
    
    // MARK: Serialize
    
    /// Seriaizes the `Cookies` for a `Request`
    public var cookieHeader: String? {
        guard !cookies.isEmpty else {
            return nil
        }
        
        let cookie: String = self.cookies.map { (name, value) in
            return "\(name)=\(value.string)"
        }.joined(separator: "; ")

        return cookie
    }

    public var setCookieHeaders: [String] {
        return self.cookies.map { $0.value.serialize(name: $0.key) }
    }
    
    // MARK: Access
    
    /// All cookies.
    public var all: [String: Value] {
        get { return cookies }
        set { cookies = newValue }
    }
    
    /// Access `HTTPCookies` by name
    public subscript(name: String) -> Value? {
        get { return cookies[name] }
        set { cookies[name] = newValue }
    }
}
