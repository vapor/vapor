/// Middleware that provides protection against cross-site scripting (XSS) attack, content type sniffing, clickjacking, insecure connection and other code injection attacks.
/// For configuration of this middleware please use the `SecureMiddleware.Configuration` object.
///
/// - note: Make sure this middleware is inserted before all your error/abort middlewares,
///         so that even the failed request responses contain proper Security Headers.
public final class SecureMiddleware: Middleware {
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
                xssProtection: "1; mode=block",
                xContentTypeOptions: "nosniff",
                xframeOptions: "SAMEORIGIN",
                strictTransportSecurity: "max-age=0",
                contentSecurityPolicy: "default-src 'self'"
            )
        }

        /// X-XSS-Protection provides protection against cross-site scripting attack (XSS)
        public let xssProtection: String?

        /// X-Content-Type-Options provides protection against overriding Content-Type
        public let xContentTypeOptions: String?

        /// X-Frame-Options can be used to indicate whether or not a browser should
        /// be allowed to render a page in a <frame>, <iframe> or <object> .
        /// Sites can use this to avoid clickjacking attacks, by ensuring that their
        /// content is not embedded into other sites.provides protection against
        /// clickjacking.
        public let xframeOptions: String?

        /// Strict-Transport-Security response header (often abbreviated as HSTS) lets a web site tell browsers that it should only be accessed using HTTPS, instead of using HTTP.
        /// max-age sets the `Strict-Transport-Security` header to indicate how
        /// long (in seconds) browsers should remember that this site is only to
        /// be accessed using HTTPS. This reduces your exposure to some SSL-stripping
        /// man-in-the-middle (MITM) attacks.
        ///
        /// ExcludeSubdomains won't include subdomains tag in the `Strict Transport Security`
        /// header, excluding all subdomains from security policy. It has no effect
        /// unless HSTSMaxAge is set to a non-zero value.
        /// Optional. Default value false.
        public let strictTransportSecurity: String?

        /// Content-Security-Policy header providing security against cross-site scripting (XSS), clickjacking and other code
        /// injection attacks resulting from execution of malicious content in the
        public let contentSecurityPolicy: String?

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
            xssProtection: String? = nil,
            xContentTypeOptions: String? = nil,
            xframeOptions: String? = nil,
            strictTransportSecurity: String? = nil,
            contentSecurityPolicy: String? = nil
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

            if let xssProtection = self.configuration.xssProtection {
                response.headers.replaceOrAdd(name: .xssProtection, value: xssProtection)
            }

            if let xContentTypeOptions = self.configuration.xContentTypeOptions {
                response.headers.replaceOrAdd(name: .xContentTypeOptions, value: xContentTypeOptions)
            }

            if let xframeOptions = self.configuration.xframeOptions {
                response.headers.replaceOrAdd(name: .xFrameOptions, value: xframeOptions)
            }

            if let strictTransportSecurity = self.configuration.strictTransportSecurity {
                response.headers.replaceOrAdd(name: .strictTransportSecurity, value: strictTransportSecurity)
            }

            if let contentSecurityPolicy = self.configuration.contentSecurityPolicy {
                response.headers.replaceOrAdd(name: .contentSecurityPolicy, value: contentSecurityPolicy)
            }

            return response
        }
    }
}
