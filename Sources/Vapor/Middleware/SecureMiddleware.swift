/// Middleware that provides protection against cross-site scripting (XSS) attack, content type sniffing, clickjacking, insecure connection and other code injection attacks.
/// For configuration of this middleware please use the `SecureMiddleware.Configuration` object.
///
/// - note: Make sure this middleware is inserted before all your error/abort middlewares,
///         so that even the failed request responses contain proper Security Headers.
public final class SecureMiddleware: Middleware {
    /// XSS Protection. with browser action.
    ///
    /// - block: Enables XSS filtering. Rather than sanitizing the page, the browser will prevent rendering of the page if an attack is detected.
    /// - report: Enables XSS filtering. If a cross-site scripting attack is detected, the browser will sanitize the page and report the violation. This uses the functionality of the CSP report-uri directive to send a report.
    public enum BrowserAction: CustomStringConvertible {
        case block
        case report(url: String)
        
        public var description: String {
            switch self {
            case .block:
                return "1; mode=block"
            case let .report(url):
                return "1; report=\(url)"
            }
        }
    }
    
    /// Cross Site Scripting (XSS) Configrations
    ///
    /// - disable: Disables XSS filtering.
    /// - enable: Enables XSS filtering with configration
    ///     - ".enable(nil)" Enables XSS filtering (usually default in browsers). If a cross-site scripting attack is detected, the browser will sanitize the page (remove the unsafe parts).
    ///     - ".enable(BrowserAction.block)" Enables XSS filtering. Rather than sanitizing the page, the browser will prevent rendering of the page if an attack is detected.
    ///     - ".enable(BrowserAction.report("<reporting-URI>"))" Enables XSS filtering. If a cross-site scripting attack is detected, the browser will sanitize the page and report the violation. This uses the functionality of the CSP report-uri directive to send a report.
    ///
    /// For more information, see [X-XSS-Protection](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-XSS-Protection)
    public enum XSSProtection: CustomStringConvertible {
        case disable
        case enable(BrowserAction?)
        
        public var description: String {
            switch self {
            case .disable:
                return "0"
            case let .enable(browserAction):
                guard let browserAction = browserAction else {
                    return "1"
                }
                return browserAction.description
            }
        }
    }
    
    /// HTTP Strict-Transport-Security (HSTS) header Configrations
    ///
    /// Strict-Transport-Security response header (often abbreviated as HSTS) lets a web site tell browsers that it should only be accessed using HTTPS, instead of using HTTP.
    /// max-age sets the `Strict-Transport-Security` header to indicate how
    /// long (in seconds) browsers should remember that this site is only to
    /// be accessed using HTTPS. This reduces your exposure to some SSL-stripping
    /// man-in-the-middle (MITM) attacks.
    ///
    /// ExcludeSubdomains won't include subdomains tag in the `Strict Transport Security`
    /// header, excluding all subdomains from security policy. It has no effect
    /// unless max-age is set to a non-zero value.
    ///
    /// For more information, see [HTTP Strict-Transport-Security (HSTS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security)
    public struct StrictTransportSecurity: CustomStringConvertible {
        /// HTTP Strict Transport Security (HSTS) policy
        ///
        /// - `default`: max-age=<expire-time>
        /// - includeSubDomains: If this optional parameter is specified, this rule applies to all of the site's subdomains as well.
        /// - preload: for Preloading Strict Transport Security
        public enum Policy {
            case `default`
            case includeSubDomains
            case preload
        }
        
        /// The time, in seconds, that the browser should remember that a site is only to be accessed using HTTPS.
        public let maxAge: Int
        
        /// HTTP Strict Transport Security (HSTS) policy
        public let policy: Policy
        
        /// Default Strict Transport Security configuration. max-age=0 with no policy
        ///
        /// - Returns: StrictTransportSecurity
        public static func `default`() -> StrictTransportSecurity {
            return .init(
                maxAge: 0,
                policy: .default
            )
        }
        
        public var description: String {
            switch policy {
            case .default:
                return "max-age=\(maxAge)"
            case .includeSubDomains:
                return "max-age=\(maxAge); includeSubDomains"
            case .preload:
                return "max-age=\(maxAge); preload"
            }
        }
    }
    
    /// The X-Frame-Options HTTP response header can be used to indicate whether or not a browser should be allowed to render a page in a <frame>, <iframe>, <embed> or <object> . Sites can use this to avoid clickjacking attacks, by ensuring that their content is not embedded into other sites.
    ///
    /// - deny: The page cannot be displayed in a frame, regardless of the site attempting to do so.
    /// - sameorigin: The page can only be displayed in a frame on the same origin as the page itself. The spec leaves it up to browser vendors to decide whether this option applies to the top level, the parent, or the whole chain, although it is argued that the option is not very useful unless all ancestors are also in the same origin. Also see Browser compatibility for support details.
    /// - allow: The page can only be displayed in a frame on the specified origin. Note that in Firefox this still suffers from the same problem as sameorigin did — it doesn't check the frame ancestors to see if they are in the same origin.
    ///
    /// For more information, see [X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options)
    public enum XFrameOptions: CustomStringConvertible {
        case deny
        case sameorigin
        case allow(from: String)
        
        public var description: String {
            switch self {
            case .deny:
                return "deny"
            case .sameorigin:
                return "sameorigin"
            case let .allow(url):
                return "allow-from \(url)"
            }
        }
    }
    
    /// The X-Content-Type-Options response HTTP header is a marker used by the server to indicate that the MIME types advertised in the Content-Type headers should not be changed and be followed. This allows to opt-out of MIME type sniffing, or, in other words, it is a way to say that the webmasters knew what they were doing.
    ///
    /// - nosniff: Blocks a request if the requested type is
    ///     - "style" and the MIME type is not "text/css", or
    ///     - "script" and the MIME type is not a JavaScript MIME type.
    ///
    /// For more information, see [X-Content-Type-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options)
    public enum XContentTypeOptions: CustomStringConvertible {
        case nosniff
        
        public var description: String {
            switch self {
            case .nosniff:
                return "nosniff"
            }
        }
    }
    
    /// Content-Security-Policy header providing security against cross-site scripting (XSS), clickjacking and other code
    /// injection attacks resulting from execution of malicious content in the trusted web page context.
    ///
    /// For more information, see [Content Security Policy (CSP)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
    public struct ContentSecurityPolicy: ExpressibleByArrayLiteral {
        /// The policy is a string containing the policy directives describing your Content Security Policy.
        public struct Policy: ExpressibleByStringLiteral {
            let string: String
            
            public init(stringLiteral value: String) {
                string = value
            }
            
            public static func defaultSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "default-src \(value)")
            }
            
            public static func scriptSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "script-src \(value)")
            }
            
            public static func imgSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "img-src \(value)")
            }
            
            public static func mediaSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "media-src \(value)")
            }
            
            public static func reportUrl(_ value: String) -> Policy {
                return .init(stringLiteral: "report-uri \(value)")
            }
        }
        
        public var directives: [Policy]
        
        public init(arrayLiteral elements: Policy...) {
            directives = elements
        }
        
        public var description: String {
            return directives.compactMap { $0.string }
                .joined(separator: "; ")
        }
    }
    
    /// Configuration used for populating headers in response for requests.
    public struct Configuration {
        /// Default SecureMiddleware configuration.
        ///
        /// - X-XSS-Protection: Default value "1; mode=block".
        /// - X-Content-Type-Options: Default value "nosniff".
        /// - X-Frame-Options: Default value "SAMEORIGIN".
        /// - Strict-Transport-Security: Default value "max-age=0".
        /// - Content-Security-Policy: Default value "default-src 'self'".
        public static func `default`() -> Configuration {
            return .init(
                xssProtection: XSSProtection.enable(BrowserAction.block),
                xContentTypeOptions: XContentTypeOptions.nosniff,
                xframeOptions: XFrameOptions.sameorigin,
                strictTransportSecurity: StrictTransportSecurity.default(),
                contentSecurityPolicy: [.defaultSrc("'self'")]
            )
        }
        
        /// X-XSS-Protection provides protection against cross-site scripting attack (XSS)
        public let xssProtection: XSSProtection?
        
        /// X-Content-Type-Options provides protection against overriding Content-Type
        public let xContentTypeOptions: XContentTypeOptions?
        
        /// X-Frame-Options can be used to indicate whether or not a browser should
        /// be allowed to render a page in a <frame>, <iframe> or <object> .
        /// Sites can use this to avoid clickjacking attacks, by ensuring that their
        /// content is not embedded into other sites.provides protection against
        /// clickjacking.
        public let xframeOptions: XFrameOptions?
        
        /// Strict-Transport-Security response header (often abbreviated as HSTS) lets a web site tell browsers that it should only be accessed using HTTPS, instead of using HTTP.
        /// max-age sets the `Strict-Transport-Security` header to indicate how
        /// long (in seconds) browsers should remember that this site is only to
        /// be accessed using HTTPS. This reduces your exposure to some SSL-stripping
        /// man-in-the-middle (MITM) attacks.
        ///
        /// ExcludeSubdomains won't include subdomains tag in the `Strict Transport Security`
        /// header, excluding all subdomains from security policy. It has no effect
        /// unless max-age is set to a non-zero value.
        public let strictTransportSecurity: StrictTransportSecurity?
        
        /// Content-Security-Policy header providing security against cross-site scripting (XSS), clickjacking and other code
        /// injection attacks resulting from execution of malicious content in the trusted web page context.
        public let contentSecurityPolicy: ContentSecurityPolicy?
        
        /// middleware for adding support for Security Headers in your responses.
        ///
        /// - Parameters:
        ///   - xssProtection: provides protection against cross-site scripting attack (XSS)
        ///   - xContentTypeOptions: provides protection against overriding Content-Type
        ///   - xframeOptions: can be used to indicate whether or not a browser should
        /// be allowed to render a page in a <frame>, <iframe> or <object> .
        /// Sites can use this to avoid clickjacking attacks, by ensuring that their
        /// content is not embedded into other sites.provides protection against
        /// clickjacking.
        ///   - strictTransportSecurity: response header (often abbreviated as HSTS) lets a web site tell browsers that it should only be accessed using HTTPS, instead of using HTTP.
        /// max-age sets the `Strict-Transport-Security` header to indicate how
        /// long (in seconds) browsers should remember that this site is only to
        /// be accessed using HTTPS. This reduces your exposure to some SSL-stripping
        /// man-in-the-middle (MITM) attacks.
        ///   - contentSecurityPolicy: header providing security against cross-site scripting (XSS), clickjacking and other code
        /// injection attacks resulting from execution of malicious content in the
        public init(
            xssProtection: XSSProtection? = nil,
            xContentTypeOptions: XContentTypeOptions? = nil,
            xframeOptions: XFrameOptions? = nil,
            strictTransportSecurity: StrictTransportSecurity? = nil,
            contentSecurityPolicy: ContentSecurityPolicy? = nil
            ) {
            self.xssProtection = xssProtection
            self.xContentTypeOptions = xContentTypeOptions
            self.xframeOptions = xframeOptions
            self.strictTransportSecurity = strictTransportSecurity
            self.contentSecurityPolicy = contentSecurityPolicy
        }
    }
    
    /// Configuration used for populating headers in response for Secure requests.
    public let configuration: Configuration
    
    /// Creates a Secure middleware with the specified configuration.
    ///
    /// - parameters:
    ///     - configuration: Configuration used for populating headers in
    ///                      response for Secure requests.
    public init(configuration: Configuration = .default()) {
        self.configuration = configuration
    }
    
    /// See `Middleware`.
    public func respond(to req: HTTPRequest, using ctx: Context, chainingTo next: Responder) -> EventLoopFuture<HTTPResponse> {
        let response = next.respond(to: req, using: ctx)
        return response.map { response in
            var response = response
            
            // Modify response headers based on SecureMiddleware settings
            
            if let xssProtection = self.configuration.xssProtection, !xssProtection.description.isEmpty {
                response.headers.replaceOrAdd(name: .xssProtection, value: xssProtection.description)
            }
            
            if let xContentTypeOptions = self.configuration.xContentTypeOptions, !xContentTypeOptions.description.isEmpty {
                response.headers.replaceOrAdd(name: .xContentTypeOptions, value: xContentTypeOptions.description)
            }
            
            if let xframeOptions = self.configuration.xframeOptions, !xframeOptions.description.isEmpty {
                response.headers.replaceOrAdd(name: .xFrameOptions, value: xframeOptions.description)
            }
            
            if let strictTransportSecurity = self.configuration.strictTransportSecurity, !strictTransportSecurity.description.isEmpty {
                response.headers.replaceOrAdd(name: .strictTransportSecurity, value: strictTransportSecurity.description)
            }
            
            if let contentSecurityPolicy = self.configuration.contentSecurityPolicy, !contentSecurityPolicy.description.isEmpty {
                response.headers.replaceOrAdd(name: .contentSecurityPolicy, value: contentSecurityPolicy.description)
            }
            
            return response
        }
    }
}
