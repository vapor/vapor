import NIO

public final class Request: CustomStringConvertible {
    public let application: Application

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
    
    // MARK: Metadata
    
    /// Route object we found for this request.
    /// This holds metadata that can be used for (for example) Metrics.
    ///
    ///     req.route?.description // "GET /hello/:name"
    ///
    public internal(set) var route: Route?

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
    
    public var logger: Logger
    
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
        get {
            return self.headers.cookie
        }
        set {
            self.headers.cookie = newValue
        }
    }
    
    /// See `CustomStringConvertible`
    public var description: String {
        var desc: [String] = []
        desc.append("\(self.method) \(self.url) HTTP/\(self.version.major).\(self.version.minor)")
        desc.append(self.headers.debugDescription)
        desc.append(self.body.description)
        return desc.joined(separator: "\n")
    }

    public let remoteAddress: SocketAddress?
    
    public let eventLoop: EventLoop
    
    public var parameters: Parameters

    public var storage: Storage
    
    public convenience init(
        application: Application,
        method: HTTPMethod = .GET,
        url: URI = "/",
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        remoteAddress: SocketAddress? = nil,
        logger: Logger = .init(label: "codes.vapor.request"),
        on eventLoop: EventLoop
    ) {
        self.init(
            application: application,
            method: method,
            url: url,
            version: version,
            headersNoUpdate: headers,
            collectedBody: collectedBody,
            logger: logger,
            on: eventLoop
        )
        if let body = collectedBody {
            self.headers.updateContentLength(body.readableBytes)
        }
    }
    
    public init(
        application: Application,
        method: HTTPMethod,
        url: URI,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headersNoUpdate headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        remoteAddress: SocketAddress? = nil,
        logger: Logger = .init(label: "codes.vapor.request"),
        on eventLoop: EventLoop
    ) {
        self.application = application
        self.method = method
        self.url = url
        self.version = version
        self.headers = headers
        if let body = collectedBody {
            self.bodyStorage = .collected(body)
        } else {
            self.bodyStorage = .none
        }
        self.remoteAddress = remoteAddress
        self.eventLoop = eventLoop
        self.parameters = .init()
        self.storage = .init()
        self.isKeepAlive = true
        self.logger = logger
        self.logger[metadataKey: "request-id"] = .string(UUID().uuidString)
    }

    /// Creates a `Response` object that has a status of 201 (Created) and includes the `Location` HTTP header.
    ///
    /// Intended to be used in routes that create a new object.
    ///
    /// ### Note ###
    /// The return type of your route should be `EventLoopFuture<Response>`
    ///
    /// ### Example ###
    /// ```swift
    /// func create(req: Request) throws -> EventLoopFuture<Response> {
    ///    let todo = try req.content.decode(Todo.self)
    ///    return todo.save(on: req.db).flatMapThrowing {
    ///        return try req.makeCreatedResponse(for: todo)
    ///    }
    /// }
    /// ```
    /// - Parameters:
    ///   - obj: The newly created model.
    ///   - mediaType: How to encode the response, defaulting to `.json`
    ///   - customLocation: The location header to use. Defaults to the current route with the `obj` ID appended.
    /// - Throws: If the object hasn't been created or the encoding fails.
    /// - Returns: A `Response` object.
    public func makeCreatedResponse<T>(for obj: T, as mediaType: HTTPMediaType = .json, at customLocation: String? = nil) throws -> Response where T: Model {
        let location: String
        if let customLocation = customLocation {
            location = customLocation
        } else {
            let id = try obj.requireID()
            location = "\(self.url.string)/\(id)"
        }

        let headers = HTTPHeaders([("Location", location)])
        let response = Response(status: .created, headers: headers)

        try response.content.encode(obj, as: mediaType)

        return response
    }
}
