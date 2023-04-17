import NIOCore
import NIOHTTP1
import NIOFoundationCompat
import NIOConcurrencyHelpers

/// An HTTP response from a server back to the client.
///
///     let res = Response(status: .ok)
///
/// See `HTTPClient` and `HTTPServer`.
// This is Sendable because all mutable properties are behind locks
public final class Response: @unchecked Sendable, CustomStringConvertible {
    /// Maximum streaming body size to use for `debugPrint(_:)`.
    private let maxDebugStreamingBodySize: Int = 1_000_000

    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion {
        get {
            concurrencyLock.withLock {
                return _version
            }
        }
        set {
            concurrencyLock.withLock {
                _version = newValue
            }
        }
    }
    
    /// The HTTP response status.
    public var status: HTTPResponseStatus {
        get {
            concurrencyLock.withLock {
                return _status
            }
        }
        set {
            concurrencyLock.withLockVoid {
                _status = newValue
            }
        }
    }
    
    /// The header fields for this HTTP response.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders {
        get {
            concurrencyLock.withLock {
                return _headers
            }
        }
        set {
            concurrencyLock.withLockVoid {
                _headers = newValue
            }
        }
    }
    
    /// The `Body`. Updating this property will also update the associated transport headers.
    ///
    ///     res.body = Response.Body(string: "Hello, world!")
    ///
    /// Also be sure to set this message's `contentType` property to a `MediaType` that correctly
    /// represents the `Body`.
    public var body: Body {
        get {
            concurrencyLock.withLock {
                return _body
            }
        }
        set {
            concurrencyLock.withLockVoid {
                _body = newValue
            }
        }
    }

    // If `true`, don't serialize the body.
    var forHeadRequest: Bool {
        get {
            concurrencyLock.withLock {
                return _forHeadRequest
            }
        }
        set {
            concurrencyLock.withLockVoid {
                _forHeadRequest = newValue
            }
        }
    }
    
    /// Optional Upgrade behavior to apply to this response.
    /// currently, websocket upgrades are the only defined case.
    public var upgrader: Upgrader? {
        get {
            concurrencyLock.withLock {
                return _upgrader
            }
        }
        set {
            concurrencyLock.withLockVoid {
                _upgrader = newValue
            }
        }
    }

    public var storage: Storage {
        get {
            concurrencyLock.withLock {
                return _storage
            }
        }
        set {
            concurrencyLock.withLockVoid {
                _storage = newValue
            }
        }
    }
    
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

    private struct _ContentContainer: Sendable, ContentContainer {
        let response: Response

        var contentType: HTTPMediaType? {
            return self.response.headers.contentType
        }

        func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = self.response.body.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body, byteBufferAllocator: self.response.body.byteBufferAllocator)
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
            var body = self.response.body.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(content, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body, byteBufferAllocator: self.response.body.byteBufferAllocator)
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
    
    private let concurrencyLock: NIOLock
    
    private var _version: HTTPVersion
    private var _status: HTTPStatus
    private var _headers: HTTPHeaders
    private var _body: Body {
        didSet { self._headers.updateContentLength(self._body.count) }
    }
    private var _forHeadRequest: Bool
    private var _upgrader: Upgrader?
    private var _storage: Storage
    
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
        body: Body = .empty
    ) {
        self.init(
            status: status,
            version: version,
            headersNoUpdate: headers,
            body: body
        )
        self.headers.updateContentLength(body.count)
    }
    
    
    /// Internal init that creates a new `Response` without sanitizing headers.
    public init(
        status: HTTPResponseStatus,
        version: HTTPVersion,
        headersNoUpdate headers: HTTPHeaders,
        body: Body
    ) {
        self.concurrencyLock = .init()
        
        self._status = status
        self._version = version
        self._headers = headers
        self._body = body
        self._storage = .init()
        self._forHeadRequest = false
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
