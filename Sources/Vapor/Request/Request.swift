import NIO

public final class Request: CustomStringConvertible {
    /// The HTTP method for this request.
    ///
    ///     httpReq.method = .GET
    ///
    public var method: HTTPMethod
    
    /// The URL used on this request.
    public var url: URL {
        get { return URL(string: self.urlString) ?? .root }
        set { self.urlString = newValue.absoluteString }
    }
    
    /// The unparsed URL string. This is usually set through the `url` property.
    ///
    ///     httpReq.urlString = "/welcome"
    ///
    public var urlString: String
    
    /// The version for this HTTP request.
    public var version: HTTPVersion
    
    /// The header fields for this HTTP request.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders
    
    internal var isKeepAlive: Bool
    
    public var query: URLContentContainer {
        get { return .init(url: self.url) }
        set { self.url = newValue.url }
    }
    
    public let logger: Logger
    
    public var body: Body {
        return Body(self)
    }
    
    internal enum BodyStorage {
        case none
        case collected(ByteBuffer)
        case stream(BodyStream)
    }
    
    internal var bodyStorage: BodyStorage
    
    /// Get and set `HTTPCookies` for this `HTTPRequest`
    /// This accesses the `"Cookie"` header.
    public var cookies: HTTPCookies {
        get { return headers.firstValue(name: .cookie).flatMap(HTTPCookies.parse) ?? [:] }
        set { newValue.serialize(into: self) }
    }
    
    /// See `CustomStringConvertible`
    public var description: String {
        var desc: [String] = []
        desc.append("\(self.method) \(self.url) HTTP/\(self.version.major).\(self.version.minor)")
        desc.append(self.headers.debugDescription)
        desc.append(self.body.description)
        return desc.joined(separator: "\n")
    }
    
    // public var upgrader: HTTPClientProtocolUpgrader?
    
    public let channel: Channel
    
    public var eventLoop: EventLoop {
        return self.channel.eventLoop
    }
    
    public var parameters: Parameters
    
    public var userInfo: [AnyHashable: Any]
    
    public convenience init(
        method: HTTPMethod = .GET,
        url: URLRepresentable = URL.root,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        on channel: Channel
    ) {
        self.init(
            method: method,
            urlString: url.convertToURL()?.absoluteString ?? "/",
            version: version,
            headersNoUpdate: headers,
            collectedBody: collectedBody,
            on: channel
        )
        if let body = collectedBody {
            self.headers.updateContentLength(body.readableBytes)
        }
    }
    
    public init(
        method: HTTPMethod,
        urlString: String,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headersNoUpdate headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        on channel: Channel
    ) {
        self.method = method
        self.urlString = urlString
        self.version = version
        self.headers = headers
        if let body = collectedBody {
            self.bodyStorage = .collected(body)
        } else {
            self.bodyStorage = .none
        }
        self.channel = channel
        self.parameters = .init()
        self.userInfo = [:]
        self.isKeepAlive = true
        var logger = Logger(label: "codes.vapor.request")
        logger.metadata["uuid"] = .string(UUID().uuidString)
        self.logger = logger
    }
}
