/// Middleware that provides protection against cross-site scripting (XSS) attack, content type sniffing, clickjacking, insecure connection and other code injection attacks.
/// For configuration of this middleware please use the `SecureMiddleware.Configuration` object.
///
/// - note: Make sure this middleware is inserted before all your error/abort middlewares,
///         so that even the failed request responses contain proper Security Headers.
public final class SecurityHeadersMiddleware: Middleware {
    /// XSS Protection. with browser action.
    ///
    /// - block: Sanitize the page and Prevent rendering of the page if an attack is detected.
    /// - report: Sanitize the page and report the violation.
    public enum BrowserAction: CustomStringConvertible {

        /// Sanitize the page and Prevent rendering of the page if an attack is detected.
        case block

        /// Sanitize the page and report the violation.
        case report(url: String)

        /// Creates the header string depending on the case of self.
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
    ///
    /// For more information, see [X-XSS-Protection](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-XSS-Protection)
    public enum XSSProtection: CustomStringConvertible {

        /// Disables XSS filtering.
        case disable

        /// Enables XSS filtering with configration.
        case enable(BrowserAction?)

        /// Creates the header string depending on the case of self.
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
    /// Strict-Transport-Security response header (often abbreviated as HSTS)
    /// lets a web site tell browsers that it should only be accessed using HTTPS,
    /// instead of using HTTP.
    ///
    /// For more information, see [HTTP Strict-Transport-Security (HSTS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security)
    public struct StrictTransportSecurity: CustomStringConvertible {
        /// HTTP Strict Transport Security (HSTS) policy
        ///
        /// - `default`: max-age in seconds
        /// - includeSubDomains: for applying rule to all of the site's subdomains as well.
        /// - preload: for Preloading Strict Transport Security
        public enum Policy {

            /// max-age in seconds
            case `default`

            /// for applying rule to all of the site's subdomains as well.
            case includeSubDomains

            /// for Preloading Strict Transport Security
            case preload
        }

        /// The time that the browser should remember that
        /// a site is only to be accessed using HTTPS.
        public let maxAge: Int

        /// HTTP Strict Transport Security (HSTS) policy
        public let policy: Policy

        /// Creates the header string depending on the case of self.
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

    /// X-Frame-Options can be used to indicate whether or not a browser should
    /// be allowed to render a page in a <frame>, <iframe> or <object> .
    ///
    /// - deny: The page cannot be displayed in a frame, regardless of the site attempting to do so.
    /// - sameorigin: The page can only be displayed in a frame on the same origin as the page.
    /// - allow: The page can only be displayed in a frame on the specified origin.
    ///
    /// For more information, see [X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options)
    public enum XFrameOptions: CustomStringConvertible {

        /// The page cannot be displayed in a frame, regardless of the site attempting to do so.
        case deny

        /// The page can only be displayed in a frame on the same origin as the page.
        case sameorigin

        /// The page can only be displayed in a frame on the specified origin.
        case allow(from: String)

        /// Creates the header string depending on the case of self.
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

    /// The X-Content-Type-Options provides protection against overriding Content-Type
    ///
    /// - nosniff: Blocks a request if the requested type if MIME type is not text/css or JavaScript
    ///
    /// For more information, see [X-Content-Type-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options)
    public enum XContentTypeOptions: CustomStringConvertible {

        /// Blocks a request if the requested type if MIME type is not text/css or JavaScript
        case nosniff

        /// Creates the header string depending on the case of self.
        public var description: String {
            switch self {
            case .nosniff:
                return "nosniff"
            }
        }
    }

    /// Content-Security-Policy header providing security against cross-site scripting (XSS),
    /// clickjacking and other code injection.
    ///
    /// For more information, see [Content Security Policy (CSP)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
    public struct ContentSecurityPolicy: ExpressibleByArrayLiteral {
        /// Configration used for the policy directives describing your Content Security Policy.
        public struct Policy: ExpressibleByStringLiteral {

            /// A textual representation of CSP.
            let string: String

            /// Instantiate a Policy struct that can be used to create a `ContentSecurityPolicy`
            ///
            /// - Parameter value: A textual representation of Policy.
            public init(stringLiteral value: String) {
                string = value
            }

            /// Instantiate a Policy struct with `default-src` Policy.
            ///
            /// - Parameter value: A textual representation of Source.
            /// - Returns: Instantiate a Policy struct.
            public static func defaultSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "default-src \(value)")
            }

            /// Instantiate a Policy struct with `script-src` Policy.
            ///
            /// - Parameter value: A textual representation of Source.
            /// - Returns: Instantiate a Policy struct.
            public static func scriptSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "script-src \(value)")
            }

            /// Instantiate a Policy struct with `img-src` Policy.
            ///
            /// - Parameter value: A textual representation of Source.
            /// - Returns: Instantiate a Policy struct.
            public static func imgSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "img-src \(value)")
            }

            /// Instantiate a Policy struct with `media-src` Policy.
            ///
            /// - Parameter value: A textual representation of Source.
            /// - Returns: Instantiate a Policy struct.
            public static func mediaSrc(_ value: String) -> Policy {
                return .init(stringLiteral: "media-src \(value)")
            }

            /// Instantiate a Policy struct with `report-uri` Policy.
            ///
            /// - Parameter value: A textual representation of Source.
            /// - Returns: Instantiate a Policy struct.
            public static func reportUrl(_ value: String) -> Policy {
                return .init(stringLiteral: "report-uri \(value)")
            }
        }

        /// An Array of Policy struct.
        public var directives: [Policy]

        /// Creates Instance of Policy struct.
        ///
        /// - Parameter elements: Instantiate a Policy struct
        public init(arrayLiteral elements: Policy...) {
            directives = elements
        }

        /// Creates the header string depending on the Policy array.
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
        public static func `default`() -> Configuration {
            return .init(
                xssProtection: XSSProtection.enable(BrowserAction.block),
                xContentTypeOptions: XContentTypeOptions.nosniff,
                xframeOptions: XFrameOptions.sameorigin
            )
        }

        /// X-XSS-Protection provides protection against cross-site scripting attack (XSS)
        public let xssProtection: XSSProtection?

        /// X-Content-Type-Options provides protection against overriding Content-Type
        public let xContentTypeOptions: XContentTypeOptions?

        /// X-Frame-Options can be used to indicate whether or not a browser should
        /// be allowed to render a page in a <frame>, <iframe> or <object> .
        public let xframeOptions: XFrameOptions?

        /// Strict-Transport-Security response header (often abbreviated as HSTS)
        /// lets a web site tell browsers that it should only be accessed using HTTPS.
        public let strictTransportSecurity: StrictTransportSecurity?

        /// Content-Security-Policy header providing security against cross-site scripting (XSS),
        /// clickjacking and other code injection.
        public let contentSecurityPolicy: ContentSecurityPolicy?

        /// middleware for adding support for Security Headers in your responses.
        ///
        /// - Parameters:
        ///   - xssProtection: provides protection against cross-site scripting attack (XSS)
        ///   - xContentTypeOptions: provides protection against overriding Content-Type
        ///   - xframeOptions: can be used to indicate whether or not a browser should be allowed to
        ///     render a page in a <frame>, <iframe> or <object> .
        ///   - strictTransportSecurity: response header (often abbreviated as HSTS) lets a web site
        ///     tell browsers that it should only be accessed using HTTPS, instead of using HTTP.
        ///   - contentSecurityPolicy: header providing security against cross-site scripting (XSS),
        ///     clickjacking and other code injection.
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
     public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let response = next.respond(to: request)
        return response.map { response in

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