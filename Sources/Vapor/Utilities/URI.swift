import CURLParser

public struct URI: ExpressibleByStringLiteral {
    public var string: String

    public init(string: String = "/") {
        self.string = string
    }

    public init(
        scheme: String? = nil,
        host: String? = nil,
        port: Int? = nil,
        path: String,
        query: String? = nil,
        fragment: String? = nil
    ) {
        var string = ""
        if let scheme = scheme {
            string += scheme + "://"
        }
        if let host = host {
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
        var url = urlparser_url()
        urlparser_parse(self.string, self.string.count, 0, &url)
        let data: urlparser_field_data
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
