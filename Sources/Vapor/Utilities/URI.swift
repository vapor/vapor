#if !canImport(Darwin)
@preconcurrency import struct Foundation.URLComponents
#else
import struct Foundation.URLComponents
#endif

/// A type for constructing and manipulating (most) Uniform Resource Indicators.
///
/// > Warning: This is **NOT** the same as Foundation's [`URL`] type!
///
/// Can be used to both parse strings containing well-formed URIs and to generate such strings from
/// a set of individual URI components.
///
/// Use of this type is (gently, for now) discouraged. Consider using Foundation's [`URL`] and/or
/// [`URLComponents`] types instead. See below for details.
///
/// ## URI is for URLs, not URIs
///
/// Thanks to both backwards compatibility requirements and name collision concerns, this type, despite
/// its name, does not actually represent a generic Uniform Resource Identifier as defined by [RFC 3986].
/// In particular, the underlying implementation is currently based on Foundation's [`URLComponents`] type,
/// whose semantics are inconsistent between different methods; in addition, its behavior has differed
/// drastically between the macOS and Linux implementations for most of its existence, and continues to do
/// so in Swift 5.9. This is not expected to be remedied until the [`swift-foundation`] package reaches a
/// 1.0 release, which as of this writing will not for quite some time yet). In short, instances of `URI`
/// may not always behave as expected according to either the spec or what Foundation does.
///
/// [RFC 3986]: https://datatracker.ietf.org/doc/html/rfc3986
/// [`swift-foundation`]: https://github.com/apple/swift-foundation
/// [`URL`]: https://developer.apple.com/documentation/foundation/url
/// [`URLComponents`]: https://developer.apple.com/documentation/foundation/urlcomponents
public struct URI: Sendable, ExpressibleByStringInterpolation, CustomStringConvertible {
    private var components: URLComponents?
    
    public init(string: String = "/") {
        self.components = URL(string: string).flatMap { .init(url: $0, resolvingAgainstBaseURL: true) }
    }

    public var description: String {
        self.string
    }

    public init(
        scheme: String?,
        userinfo: String?,
        host: String? = nil,
        port: Int? = nil,
        path: String,
        query: String? = nil,
        fragment: String? = nil
    ) {
        self.init(
            scheme: Scheme(scheme),
            userinfo: userinfo,
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment
        )
    }

    public init(scheme: String?, host: String? = nil, port: Int? = nil, path: String, query: String? = nil, fragment: String? = nil) {
        self.init(scheme: scheme, userinfo: nil, host: host, port: port, path: path, query: query, fragment: fragment)
    }
    
    public init(scheme: Scheme = .init(), host: String? = nil, port: Int? = nil, path: String, query: String? = nil, fragment: String? = nil) {
        self.init(scheme: scheme, userinfo: nil, host: host, port: port, path: path, query: query, fragment: fragment)
    }
    
    /// Construct a ``URI`` from various subcomponents.
    ///
    /// Percent encoding is added to each component (if necessary) automatically. There is currently no
    /// way to change this behavior; use `URLComponents` instead if this is insufficient.
    ///
    /// > Warning: For backwards compatibility reasons, if the `path` component is specified in isolation
    /// > (e.g. all other components are `nil`), the path is parsed as if by the ``init(string:)`` initializer.
    ///
    /// > Important: If the `path` does not begin with a `/`, one is prepended. This occurs even if the path
    /// > is specified in isolation (as described above).
    public init(
        scheme: Scheme = .init(),
        userinfo: String?,
        host: String? = nil,
        port: Int? = nil,
        path: String,
        query: String? = nil,
        fragment: String? = nil
    ) {
        let path = path.first == "/" ? path : "/\(path)"
        var components: URLComponents!
        
        if scheme.value == nil, userinfo == nil, host == nil, port == nil, query == nil, fragment == nil {
            // If only a path is given, treat it as a string to parse. (This behavior is awful, but must be kept for compatibility.)
            components = URL(string: path).flatMap { .init(url: $0, resolvingAgainstBaseURL: true) }
        } else {
            // N.B.: We perform percent encoding manually and unconditionally on each non-nil component because the
            // behavior of URLComponents is completely different on Linux than on macOS for inputs which are already
            // fully or partially percent-encoded, as well as inputs which contain invalid characters (especially
            // for the host component). This is the only way to provide consistent behavior (and to avoid various
            // fatalError()s in URLComponents on Linux).
            components = .init()
            components.scheme = scheme.value?.addingPercentEncoding(withAllowedCharacters: .urlSchemeAllowed)
            if let host {
                if let creds = userinfo?.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false), !creds[0].isEmpty {
                    components.percentEncodedUser = creds[0].addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
                    if creds.count > 1, !creds[1].isEmpty {
                        components.percentEncodedPassword = creds[1].addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed)
                    }
                }
                // TODO: Use the `encodedHost` polyfill
                #if canImport(Darwin)
                if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                    components.encodedHost = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                } else {
                    components.percentEncodedHost = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                }
                #else
                components.percentEncodedHost = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                #endif
                components.port = port
            } else {
                // TODO: Should this be enforced?
                // assert(userinfo == nil, "Can't provide userinfo without an authority (hostname)")
                // assert(port == nil, "Can't provide userinfo without an authority (hostname)")
            }
            components.percentEncodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlCorrectPathAllowed) ?? "/"
            components.percentEncodedQuery = query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            components.percentEncodedFragment = fragment?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
        }
        self.components = components
    }

    public init(stringLiteral value: String) {
        self.init(string: value)
    }

    public var scheme: String? {
        get { self.components?.scheme }
        set { self.components?.scheme = newValue }
    }
    
    public var userinfo: String? {
        get { self.components?.user.map { "\($0)\(self.components?.password.map { ":\($0)" } ?? "")" } }
        set {
            if let userinfoData = newValue?.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false) {
                self.components?.user = .init(userinfoData[0])
                self.components?.password = userinfoData.count > 1 ? .init(userinfoData[1]) : nil
            } else {
                self.components?.user = nil
            }
        }
    }

    public var host: String? {
        get { self.components?.host }
        set { self.components?.host = newValue }
    }

    public var port: Int? {
        get { self.components?.port }
        set { self.components?.port = newValue }
    }

    public var path: String {
        get { self.components?.path ?? "/" }
        set { self.components?.path = newValue }
    }

    public var query: String? {
        get { self.components?.query }
        set { self.components?.query = newValue }
    }

    public var percentEncodedQuery: String? {
        get { self.components?.percentEncodedQuery }
        set { self.components?.percentEncodedQuery = newValue }
    }
    
    public var fragment: String? {
        get { self.components?.fragment }
        set { self.components?.fragment = newValue }
    }

    public var string: String {
        #if canImport(Darwin)
        self.components?.string ?? ""
        #else
        // On Linux, URLComponents incorrectly treats `;` as *not* allowed in the path component.
        self.components?.string?.replacingOccurrences(of: "%3B", with: ";") ?? ""
        #endif
    }
    
}

extension URI {
    /// A URI scheme, as defined by [RFC 3986 § 3.1] and [RFC 7595].
    ///
    /// [RFC 3986 § 3.1]: https://datatracker.ietf.org/doc/html/rfc3986#section-3.1
    /// [RGC 7595]: https://datatracker.ietf.org/doc/html/rfc7595
    public struct Scheme {
        /// The string representation of the scheme.
        public let value: String?
        
        /// Designated initializer.
        ///
        /// - Parameter value: The string representation for the desired scheme.
        public init(_ value: String? = nil) { self.value = value }

        // MARK: - "Well-known" schemes
        
        /// HyperText Transfer Protocol (HTTP)
        ///
        /// > Registration: [RFC 9110 § 4.2.1](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.1)
        public static let http: Self = "http"
        
        /// Secure HyperText Transfer Protocol (HTTPS)
        ///
        /// > Registration: [RFC 9110 § 4.2.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.2)
        public static let https: Self = "https"
        
        /// HyperText Transfer Protocol (HTTP) over Unix Domain Sockets.
        ///
        /// The socket path must be given as the URI's "host" component, appropriately percent-encoded. The
        /// ``URI/init(scheme:userinfo:host:port:path:query:fragment:)`` initializer adds such encoding
        /// automatically. To manually apply the correct encoding, use:
        ///
        /// ```swift
        /// socketPath.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        /// ```
        /// 
        /// > Registration: None (non-standard)
        public static let httpUnixDomainSocket: Self = "http+unix"
        
        /// Secure HyperText Transfer Protocol (HTTPS) over Unix Domain Sockets.
        ///
        /// The socket path must be given as the URI's "host" component, appropriately percent-encoded. The
        /// ``URI/init(scheme:userinfo:host:port:path:query:fragment:)`` initializer adds such encoding
        /// automatically. To manually apply the correct encoding, use:
        ///
        /// ```swift
        /// socketPath.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        /// ```
        ///
        /// > Note: The primary use case for this scheme is for local communication with servers (most
        /// > often database servers) which require TLS client certificate authentication. In most other
        /// > situations, the added encryption is unnecessary and will just slow things down.
        /// >
        /// > (Well, unless your security concerns include other processes spying on your server's
        /// > communications when using UNIX sockets. But since doing that would require having already
        /// > compromised the host kernel ("It rather involved being on the other side of this airtight
        /// > hatchway."), it seems fairly safe to say such a concern would be moot.)
        ///
        /// > Registration: None (non-standard)
        public static let httpsUnixDomainSocket: Self = "https+unix"
        
        // MARK: End of "well-known" schemes -
    }
}

extension URI.Scheme: ExpressibleByStringInterpolation {
    // See `ExpressibleByStringInterpolation.init(stringLiteral:)`.
    public init(stringLiteral value: String) { self.init(value) }
}

extension URI.Scheme: CustomStringConvertible {
    // See `CustomStringConvertible.description`.
    public var description: String { self.value ?? "" }
}

extension URI.Scheme: Sendable {}

extension CharacterSet {
    /// The set of characters allowed in a URI scheme, as per [RFC 3986 § 3.1].
    ///
    /// [RFC 3986 § 3.1]: https://datatracker.ietf.org/doc/html/rfc3986#section-3.1
    fileprivate static var urlSchemeAllowed: Self {
        // Intersect the alphanumeric set plus additional characters with the host-allowed set to ensure
        // we get only ASCII codepoints in the result.
        Self.urlHostAllowed.intersection(Self.alphanumerics.union(.init(charactersIn: "+-.")))
    }
    
    /// The set of characters allowed in a URI path, as per [RFC 3986 § 3.3].
    ///
    /// > Note: This is identical to the built-in `urlPathAllowed` on macOS; on Linux it adds the missing
    /// > semicolon character to the set.
    ///
    /// [RFC 3986 § 3.3]: https://datatracker.ietf.org/doc/html/rfc3986#section-3.3
    fileprivate static var urlCorrectPathAllowed: Self {
        #if canImport(Darwin)
        .urlPathAllowed
        #else
        .urlPathAllowed.union(.init(charactersIn: ";"))
        #endif
    }
}
