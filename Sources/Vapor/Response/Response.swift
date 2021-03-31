import NIO
import NIOHTTP1
import NIOFoundationCompat

/// An HTTP response from a server back to the client.
///
///     let res = Response(status: .ok)
///
/// See `HTTPClient` and `HTTPServer`.
public final class Response: CustomStringConvertible {
    /// Maximum streaming body size to use for `debugPrint(_:)`.
    private let maxDebugStreamingBodySize: Int = 1_000_000

    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion
    
    /// The HTTP response status.
    public var status: HTTPResponseStatus
    
    /// The header fields for this HTTP response.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders
    
    /// The `Body`. Updating this property will also update the associated transport headers.
    ///
    ///     res.body = Response.Body(string: "Hello, world!")
    ///
    /// Also be sure to set this message's `contentType` property to a `MediaType` that correctly
    /// represents the `Body`.
    public var body: Body {
        didSet { self.headers.updateContentLength(self.body.count) }
    }

    // If `true`, don't serialize the body.
    var forHeadRequest: Bool

    internal enum Upgrader {
        case webSocket(maxFrameSize: WebSocketMaxFrameSize, shouldUpgrade: (() -> EventLoopFuture<HTTPHeaders?>), onUpgrade: (WebSocket) -> ())
    }
    
    internal var upgrader: Upgrader?

    public var storage: Storage
    
    /// Get and set `HTTPCookies` for this `Response`.
    /// This accesses the `"Set-Cookie"` header.
    public var cookies: HTTPCookies {
        get {
            return self.headers.setCookie ?? .init()
        }
        set {
            self.headers.setCookie = newValue
        }
    }
    
    /// See `CustomStringConvertible`
    public var description: String {
        var desc: [String] = []
        desc.append("HTTP/\(self.version.major).\(self.version.minor) \(self.status.code) \(self.status.reasonPhrase)")
        desc.append(self.headers.debugDescription)
        desc.append(self.body.description)
        return desc.joined(separator: "\n")
    }

    // MARK: Content

    private struct _ContentContainer: ContentContainer {
        let response: Response

        var contentType: HTTPMediaType? {
            return self.response.headers.contentType
        }

        func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = self.response.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body)
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.response.body.buffer else {
                throw Abort(.unprocessableEntity)
            }
            return try decoder.decode(D.self, from: body, headers: self.response.headers)
        }

        func encode<C>(_ content: C, using encoder: ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            var body = self.response.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(content, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body)
        }

        func decode<C>(_ content: C.Type, using decoder: ContentDecoder) throws -> C where C : Content {
            guard let body = self.response.body.buffer else {
                throw Abort(.unprocessableEntity)
            }
            var decoded = try decoder.decode(C.self, from: body, headers: self.response.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: ContentContainer {
        get {
            return _ContentContainer(response: self)
        }
        set {
            // ignore since Request is a reference type
        }
    }

    private var byteBufferAllocator: ByteBufferAllocator
    
    // MARK: Init
    
    /// Creates a new `Response`.
    ///
    ///     let res = Response(status: .ok)
    ///
    /// - parameters:
    ///     - status: `HTTPResponseStatus` to use. This defaults to `HTTPResponseStatus.ok`
    ///     - version: `HTTPVersion` of this response, should usually be (and defaults to) 1.1.
    ///     - headers: `HTTPHeaders` to include with this response.
    ///                Defaults to empty headers.
    ///                The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically.
    ///     - body: `Body` for this response, defaults to an empty body.
    ///             See `Response.Body` for more information.
    public convenience init(
        status: HTTPResponseStatus = .ok,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: Body = .empty,
        byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()
    ) {
        self.init(
            status: status,
            version: version,
            headersNoUpdate: headers,
            body: body,
            byteBufferAllocator: byteBufferAllocator
        )
        self.headers.updateContentLength(body.count)
    }
    
    
    /// Internal init that creates a new `Response` without sanitizing headers.
    public init(
        status: HTTPResponseStatus,
        version: HTTPVersion,
        headersNoUpdate headers: HTTPHeaders,
        body: Body,
        byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
        self.storage = .init()
        self.forHeadRequest = false
        self.byteBufferAllocator = byteBufferAllocator
    }
}


extension HTTPHeaders {
    mutating func updateContentLength(_ contentLength: Int) {
        let count = contentLength.description
        switch contentLength {
        case -1:
            self.remove(name: .contentLength)
            if "chunked" != self.first(name: .transferEncoding) {
                self.add(name: .transferEncoding, value: "chunked")
            }
        default:
            self.remove(name: .transferEncoding)
            if count != self.first(name: .contentLength) {
                self.replaceOrAdd(name: .contentLength, value: count)
            }
        }
    }
}
