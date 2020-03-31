import NIO
import NIOSSL

/// Configuration for Vapor's Client (where support is possible)
public struct ClientConfiguration {
    /// TLS configuration, defaults to `TLSConfiguration.forClient()`.
    public var tlsConfiguration: TLSConfiguration?
    /// Enables following 3xx redirects automatically, defaults to `false`.
    ///
    /// Following redirects are supported:
    ///  - `301: Moved Permanently`
    ///  - `302: Found`
    ///  - `303: See Other`
    ///  - `304: Not Modified`
    ///  - `305: Use Proxy`
    ///  - `307: Temporary Redirect`
    ///  - `308: Permanent Redirect`
    public var redirectConfiguration: RedirectConfiguration
    /// Default client timeout, defaults to no timeouts.
    public var timeout: Timeout
    /// Upstream proxy, defaults to no proxy.
    public var proxy: Proxy?
    /// Enables automatic body decompression such as gzip
    public var decompression: Decompression
    /// Ignore TLS unclean shutdown error, defaults to `false`.
    public var ignoreUncleanSSLShutdown: Bool
    
    public init(tlsConfiguration: TLSConfiguration? = nil,
                redirectConfiguration: RedirectConfiguration? = nil,
                timeout: Timeout = Timeout(),
                proxy: Proxy? = nil,
                ignoreUncleanSSLShutdown: Bool = false,
                decompression: Decompression = .disabled) {
        self.tlsConfiguration = tlsConfiguration
        self.redirectConfiguration = redirectConfiguration ?? RedirectConfiguration()
        self.timeout = timeout
        self.proxy = proxy
        self.ignoreUncleanSSLShutdown = ignoreUncleanSSLShutdown
        self.decompression = decompression
    }
    
    public init(certificateVerification: CertificateVerification,
                redirectConfiguration: RedirectConfiguration? = nil,
                timeout: Timeout = Timeout(),
                proxy: Proxy? = nil,
                ignoreUncleanSSLShutdown: Bool = false,
                decompression: Decompression = .disabled) {
        self.tlsConfiguration = TLSConfiguration.forClient(certificateVerification: certificateVerification)
        self.redirectConfiguration = redirectConfiguration ?? RedirectConfiguration()
        self.timeout = timeout
        self.proxy = proxy
        self.ignoreUncleanSSLShutdown = ignoreUncleanSSLShutdown
        self.decompression = decompression
    }
}

extension ClientConfiguration {
    /// Timeout configuration
    public struct Timeout {
        /// Specifies connect timeout.
        public var connect: TimeAmount?
        /// Specifies read timeout.
        public var read: TimeAmount?

        /// Create timeout.
        ///
        /// - parameters:
        ///     - connect: `connect` timeout.
        ///     - read: `read` timeout.
        public init(connect: TimeAmount? = nil, read: TimeAmount? = nil) {
            self.connect = connect
            self.read = read
        }
    }

    /// Specifies redirect processing settings.
    public struct RedirectConfiguration {
        enum Configuration {
            /// Redirects are not followed.
            case disallow
            /// Redirects are followed with a specified limit.
            case follow(max: Int, allowCycles: Bool)
        }

        var configuration: Configuration

        init() {
            self.configuration = .follow(max: 5, allowCycles: false)
        }

        init(configuration: Configuration) {
            self.configuration = configuration
        }

        /// Redirects are not followed.
        public static let disallow = RedirectConfiguration(configuration: .disallow)

        /// Redirects are followed with a specified limit.
        ///
        /// - parameters:
        ///     - max: The maximum number of allowed redirects.
        ///     - allowCycles: Whether cycles are allowed.
        ///
        /// - warning: Cycle detection will keep all visited URLs in memory which means a malicious server could use this as a denial-of-service vector.
        public static func follow(max: Int, allowCycles: Bool) -> RedirectConfiguration { return .init(configuration: .follow(max: max, allowCycles: allowCycles)) }
    }
    
    /// Proxy server configuration
    /// Specifies the remote address of an HTTP proxy.
    ///
    /// Adding an `Proxy` to your client's `HTTPClient.Configuration`
    /// will cause requests to be passed through the specified proxy using the
    /// HTTP `CONNECT` method.
    ///
    /// If a `TLSConfiguration` is used in conjunction with `HTTPClient.Configuration.Proxy`,
    /// TLS will be established _after_ successful proxy, between your client
    /// and the destination server.
    public struct Proxy {
        /// Specifies Proxy server host.
        public var host: String
        /// Specifies Proxy server port.
        public var port: Int
        /// Specifies Proxy server authorization.
        public var authorization: Authorization?

        /// Create proxy.
        ///
        /// - parameters:
        ///     - host: proxy server host.
        ///     - port: proxy server port.
        public static func server(host: String, port: Int) -> Proxy {
            return .init(host: host, port: port, authorization: nil)
        }

        /// Create proxy.
        ///
        /// - parameters:
        ///     - host: proxy server host.
        ///     - port: proxy server port.
        ///     - authorization: proxy server authorization.
        public static func server(host: String, port: Int, authorization: Authorization? = nil) -> Proxy {
            return .init(host: host, port: port, authorization: authorization)
        }
    }
    
    /// HTTP authentication
    public struct Authorization {
        enum Scheme {
            case Basic(String)
            case Bearer(String)
        }

        let scheme: Scheme

        private init(scheme: Scheme) {
            self.scheme = scheme
        }

        public static func basic(username: String, password: String) -> Authorization {
            return .basic(credentials: Data("\(username):\(password)".utf8).base64EncodedString())
        }

        public static func basic(credentials: String) -> Authorization {
            return .init(scheme: .Basic(credentials))
        }

        public static func bearer(tokens: String) -> Authorization {
            return .init(scheme: .Bearer(tokens))
        }

        public var headerValue: String {
            switch self.scheme {
            case .Basic(let credentials):
                return "Basic \(credentials)"
            case .Bearer(let tokens):
                return "Bearer \(tokens)"
            }
        }
    }
    
    /// Specifies decompression settings.
    public enum Decompression {
        /// Decompression is disabled.
        case disabled
        /// Decompression is enabled.
        case enabled(limit: NIOHTTPDecompression.DecompressionLimit)
    }
}
