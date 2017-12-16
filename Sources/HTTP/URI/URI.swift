import Dispatch
/*
 https://tools.ietf.org/html/rfc3986#section-3
 
 URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
 
 The following are two example URIs and their component parts:
 
 foo://example.com:8042/over/there?name=ferret#nose
 \_/   \______________/\_________/ \_________/ \__/
 |           |            |            |        |
 scheme     authority       path        query   fragment
 |   _____________________|__
 / \ /                        \
 urn:example:animal:ferret:nose
 
 [Learn More →](https://docs.vapor.codes/3.0/http/uri/)
 */
public struct URI: Codable {
    // https://tools.ietf.org/html/rfc3986#section-3.1
    public var scheme: String?
    
    // https://tools.ietf.org/html/rfc3986#section-3.2.1
    public var userInfo: UserInfo?
    // https://tools.ietf.org/html/rfc3986#section-3.2.2
    public var hostname: String?
    // https://tools.ietf.org/html/rfc3986#section-3.2.3
    public var port: Port?
    
    // https://tools.ietf.org/html/rfc3986#section-3.3
    public private(set) var pathBytes: [UInt8]
    
    // https://tools.ietf.org/html/rfc3986#section-3.3
    public var path: String {
        get {
            return String(bytes: pathBytes, encoding: .utf8) ?? ""
        }
        set {
            self.pathBytes = [UInt8](newValue.utf8)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.4
    public var query: String?
    
    // https://tools.ietf.org/html/rfc3986#section-3.5
    public var fragment: String?
    
    /// Creates a new URI
    public init(
        scheme: String? = nil,
        userInfo: UserInfo? = nil,
        hostname: String? = nil,
        port: Port? = nil,
        path: String = "/",
        query: String? = nil,
        fragment: String? = nil
    ) {
        let path = path.first == "/" ? path : "/" + path
        
        self.init(
            scheme: scheme,
            userInfo: userInfo,
            hostname: hostname,
            port: port,
            pathBytes: Array(path.utf8),
            query: query,
            fragment: fragment
        )
    }
    
    internal init(
        scheme: String? = nil,
        userInfo: UserInfo? = nil,
        hostname: String? = nil,
        port: Port? = nil,
        pathBytes: [UInt8],
        query: String? = nil,
        fragment: String? = nil
    ) {
        self.scheme = scheme?.lowercased()
        self.userInfo = userInfo
        self.hostname = hostname?.lowercased()
        if let scheme = scheme {
            self.port = port ?? URI.defaultPorts[scheme]
        } else {
            self.port = nil
        }
        
        self.pathBytes = pathBytes
        self.query = query
        self.fragment = fragment
    }
    
    /// Decodes URI from a String
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        self.init(stringLiteral: try container.decode(String.self))
    }
    
    /// Encodes URI to a String
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension URI {
    /// https://tools.ietf.org/html/rfc3986#section-3.2.1
    public struct UserInfo: Codable {
        public let username: String
        public let info: String?

        public init(username: String, info: String? = nil) {
            self.username = username
            self.info = info
        }
    }
}

extension URI.UserInfo: CustomStringConvertible {
    public var description: String {
        var d = username
        if let info = info {
            d += ":\(info)"
        }
        return d
    }
}

public typealias Port = UInt16

extension URI {
    /// Default ports known to correspond with given schemes.
    /// Expand as possible
    public static let defaultPorts: [String: Port] = [
        "http": 80,
        "https": 443,
        "ws": 80,
        "wss": 443
    ]
    
    /// The default port for scheme associated with this URI if known
    public var defaultPort: Port? {
        guard let scheme = scheme else {
            return nil
        }
        return URI.defaultPorts[scheme]
    }
}

extension URI: RawRepresentable, CustomStringConvertible {
    public typealias RawValue = String

    public init?(rawValue: String) {
        self = .init(stringLiteral: rawValue)
    }
    
    public var rawValue: String {
        var uri = ""
        
        if let scheme = scheme {
            uri += scheme + "://"
        }
        
        if let userInfo = userInfo {
            uri += userInfo.description + "@"
        }
        
        if let hostname = hostname {
            uri += hostname
        }
        
        if let port = port {
            uri += ":" + port.description
        }
        
        uri += path
        
        if let query = query {
            uri += "?" + query
        }
        
        if let fragment = fragment {
            uri += "#" + fragment
        }
        
        return uri
    }

    public var description: String {
        return self.rawValue
    }
}

// MARK: String literal
import Foundation

extension URI: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = URIParser().parse(data: Data(value.utf8))
    }
}


