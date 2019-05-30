import NIO

public final class Request: CustomStringConvertible {
    /// The HTTP method for this request.
    ///
    ///     httpReq.method = .GET
    ///
    public var method: HTTPMethod
    
    /// The URL used on this request.
    public var url: URI
    
    /// The version for this HTTP request.
    public var version: HTTPVersion
    
    /// The header fields for this HTTP request.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders
    
    internal var isKeepAlive: Bool

    // MARK: Content

    private struct _URLQueryContainer: URLQueryContainer {
        let request: Request

        func decode<D>(_ decodable: D.Type, using decoder: URLQueryDecoder) throws -> D
            where D: Decodable
        {
            return try decoder.decode(D.self, from: self.request.url)
        }

        func encode<E>(_ encodable: E, using encoder: URLQueryEncoder) throws
            where E: Encodable
        {
            try encoder.encode(encodable, to: &self.request.url)
        }
    }
    
    public var query: URLQueryContainer {
        get {
            return _URLQueryContainer(request: self)
        }
        set {
            // ignore since Request is a reference type
        }
    }

    private struct _ContentContainer: ContentContainer {
        let request: Request

        var contentType: HTTPMediaType? {
            return self.request.headers.contentType
        }

        func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = ByteBufferAllocator().buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.request.headers)
            self.request.bodyStorage = .collected(body)
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.request.body.data else {
                self.request.logger.error("Decoding streaming bodies not supported")
                throw Abort(.unprocessableEntity)
            }
            return try decoder.decode(D.self, from: body, headers: self.request.headers)
        }
    }

    public var content: ContentContainer {
        get {
            return _ContentContainer(request: self)
        }
        set {
            // ignore since Request is a reference type
        }
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
        url: URI = "/",
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        on channel: Channel
    ) {
        self.init(
            method: method,
            url: url,
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
        url: URI,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headersNoUpdate headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        on channel: Channel
    ) {
        self.method = method
        self.url = url
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
        logger[metadataKey: "uuid"] = .string(UUID().uuidString)
        self.logger = logger
    }
}
