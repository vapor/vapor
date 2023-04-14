import CVaporURLParser

public struct URI: Sendable, ExpressibleByStringInterpolation, CustomStringConvertible {
    /// A URI's scheme.
    public struct Scheme: ExpressibleByStringInterpolation {
        /// HTTP
        public static let http: Self = "http"
        
        /// HTTPS
        public static let https: Self = "https"
        
        /// HTTP over Unix Domain Socket Paths. The socket path should be encoded as the host in the URI, making sure to encode any special characters:
        /// ```
        /// host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        /// ```
        /// Do note that URI's initializer will encode the host in this way if you use `init(scheme:host:port:path:query:fragment:)`.
        public static let httpUnixDomainSocket: Self = "http+unix"
        
        /// HTTPS over Unix Domain Socket Paths. The socket path should be encoded as the host in the URI, making sure to encode any special characters:
        /// ```
        /// host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        /// ```
        /// Do note that URI's initializer will encode the host in this way if you use `init(scheme:host:port:path:query:fragment:)`.
        public static let httpsUnixDomainSocket: Self = "https+unix"
        
        public let value: String?
        
        public init(stringLiteral value: String) {
            self.value = value
        }
        
        public init(_ value: String? = nil) {
            self.value = value
        }
    }
    
    public var string: String

    public init(string: String = "/") {
        self.string = string
    }

    public var description: String {
        return self.string
    }

    public init(
        scheme: String?,
        host: String? = nil,
        port: Int? = nil,
        path: String,
        query: String? = nil,
        fragment: String? = nil
    ) {
        self.init(
            scheme: Scheme(scheme),
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment
        )
    }
    
    public init(
        scheme: Scheme = Scheme(),
        host: String? = nil,
        port: Int? = nil,
        path: String,
        query: String? = nil,
        fragment: String? = nil
    ) {
        var string = ""
        if let scheme = scheme.value {
            string += scheme + "://"
        }
        if let host = host?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            string += host
        }
        if let port = port {
            string += ":" + port.description
        }
        if path.hasPrefix("/") {
            string += path
        } else {
            string += "/" + path
        }
        if let query = query {
            string += "?" + query
        }
        if let fragment = fragment {
            string += "#" + fragment
        }
        self.string = string
    }

    public init(stringLiteral value: String) {
        self.init(string: value)
    }

    private enum Component {
        case scheme, host, port, path, query, fragment, userinfo
    }

    public var scheme: String? {
        get {
            return self.parse(.scheme)
        }
        set {
            self = .init(
                scheme: newValue,
                host: self.host,
                port: self.port,
                path: self.path,
                query: self.query,
                fragment: self.fragment
            )
        }
    }

    public var host: String? {
        get {
            return self.parse(.host)
        }
        set {
            self = .init(
                scheme: self.scheme,
                host: newValue,
                port: self.port,
                path: self.path,
                query: self.query,
                fragment: self.fragment
            )
        }
    }

    public var port: Int? {
        get {
            return self.parse(.port).flatMap(Int.init)
        }
        set {
            self = .init(
                scheme: self.scheme,
                host: self.host,
                port: newValue,
                path: self.path,
                query: self.query,
                fragment: self.fragment
            )
        }
    }

    public var path: String {
        get {
            return self.parse(.path) ?? ""
        }
        set {
            self = .init(
                scheme: self.scheme,
                host: self.host,
                port: self.port,
                path: newValue,
                query: self.query,
                fragment: self.fragment
            )
        }
    }

    public var query: String? {
        get {
            return self.parse(.query)
        }
        set {
            self = .init(
                scheme: self.scheme,
                host: self.host,
                port: self.port,
                path: self.path,
                query: newValue,
                fragment: self.fragment
            )
        }
    }

    public var fragment: String? {
        get {
            return self.parse(.fragment)
        }
        set {
            self = .init(
                scheme: self.scheme,
                host: self.host,
                port: self.port,
                path: self.path,
                query: self.query,
                fragment: newValue
            )
        }
    }

    private func parse(_ component: Component) -> String? {
        var url = vapor_urlparser_url()
        vapor_urlparser_parse(self.string, self.string.count, 0, &url)
        let data: vapor_urlparser_field_data
        switch component {
        case .scheme:
            data = url.field_data.0
        case .host:
            data = url.field_data.1
        case .port:
            data = url.field_data.2
        case .path:
            data = url.field_data.3
        case .query:
            data = url.field_data.4
        case .fragment:
            data = url.field_data.5
        case .userinfo:
            data = url.field_data.6
        }
        if data.len == 0 {
            return nil
        }
        let start = self.string.index(self.string.startIndex, offsetBy: numericCast(data.off))
        let end = self.string.index(start, offsetBy: numericCast(data.len))
        return String(self.string[start..<end])
    }
}
