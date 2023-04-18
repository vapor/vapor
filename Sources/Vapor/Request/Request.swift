import Foundation
import NIOCore
import NIOHTTP1
import Logging
#warning("fix")
@preconcurrency import RoutingKit
import NIOConcurrencyHelpers

/// Represents an HTTP request in an application.
// All mutable properties are put behind locks where applicable so this
// can be Sendable
public final class Request: Sendable, CustomStringConvertible {
    public let application: Application

    /// The HTTP method for this request.
    ///
    ///     httpReq.method = .GET
    ///
    public var method: HTTPMethod {
        get {
            return _method.withLockedValue { $0 }
        }
        set {
            _method.withLockedValue { $0 = newValue }
        }
    }
    
    /// The URL used on this request.
    public var url: URI {
        get {
            return _url.withLockedValue { $0 }
        }
        set {
            _url.withLockedValue { $0 = newValue }
        }
    }
    
    /// The version for this HTTP request.
    public var version: HTTPVersion {
        get {
            return _version.withLockedValue { $0 }
        }
        set {
            _version.withLockedValue { $0 = newValue }
        }
    }
    
    /// The header fields for this HTTP request.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders {
        get {
            return _headers.withLockedValue { $0 }
        }
        set {
            _headers.withLockedValue { $0 = newValue }
        }
    }
    
    /// A uniquely generated ID for each request
    public let id: String
    
    // MARK: Metadata
    
    /// Route object we found for this request.
    /// This holds metadata that can be used for (for example) Metrics.
    ///
    ///     req.route?.description // "GET /hello/:name"
    ///
    public var route: Route? {
        get {
            return _route.withLockedValue { $0 }
        }
        set {
            _route.withLockedValue { $0 = newValue }
        }
    }

    /// We try to determine true peer address if load balacer or reversed proxy provided info in headers
    ///
    /// Priority of getting value from headers is as following:
    ///
    /// 1. try the "Forwarded" header (e.g. for=192.0.2.60; proto=http; by=203.0.113.43)
    /// 2. try the "X-Forwarded-For" header (e.g. client_IP, proxy1_IP, proxy2_IP)
    /// 3. fallback to the socket's remote address provided by SwiftNIO ( e.g. 192.0.2.60:62934)
    /// in 1. and 2. will use port 80 as default port, and  3. will have port number provided by NIO if any
    public var peerAddress: SocketAddress? {
        if let clientAddress = headers.forwarded.first?.for {
            return try? SocketAddress.init(ipAddress: clientAddress, port: 80)
        }

        if let xForwardedFor = headers.first(name: .xForwardedFor) {
            return try? SocketAddress.init(ipAddress: xForwardedFor, port: 80)
        }

        return self.remoteAddress
    }

    // MARK: Content

    private struct _URLQueryContainer: Sendable, URLQueryContainer {
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

    private struct _ContentContainer: Sendable, ContentContainer {
        let request: Request

        var contentType: HTTPMediaType? {
            return self.request.headers.contentType
        }

        func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = self.request.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.request.headers)
            self.request.bodyStorage = .collected(body)
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.request.body.data else {
                self.request.logger.debug("Request body is empty. If you're trying to stream the body, decoding streaming bodies not supported")
                throw Abort(.unprocessableEntity)
            }
            return try decoder.decode(D.self, from: body, headers: self.request.headers)
        }

        func encode<C>(_ content: C, using encoder: ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            var body = self.request.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(content, to: &body, headers: &self.request.headers)
            self.request.bodyStorage = .collected(body)
        }

        func decode<C>(_ content: C.Type, using decoder: ContentDecoder) throws -> C where C : Content {
            guard let body = self.request.body.data else {
                self.request.logger.debug("Request body is empty. If you're trying to stream the body, decoding streaming bodies not supported")
                throw Abort(.unprocessableEntity)
            }
            var decoded = try decoder.decode(C.self, from: body, headers: self.request.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    /// This container is used to read your `Decodable` type using a `ContentDecoder` implementation.
    /// If no `ContentDecoder` is provided, a `Request`'s `Content-Type` header is used to select a registered decoder.
    public var content: ContentContainer {
        get {
            return _ContentContainer(request: self)
        }
        set {
            // ignore since Request is a reference type
        }
    }
    
    /// This Logger from Apple's `swift-log` Package is preferred when logging in the context of handing this Request.
    /// Vapor already provides metadata to this logger so that multiple logged messages can be traced back to the same request.
    public var logger: Logger {
        get {
            return _logger.withLockedValue { $0 }
        }
        set {
            _logger.withLockedValue { $0 = newValue }
        }
    }
    
    public var body: Body {
        return Body(self)
    }
    
    internal enum BodyStorage: Sendable {
        case none
        case collected(ByteBuffer)
        case stream(BodyStream)
    }
    
    internal var bodyStorage: BodyStorage {
        get {
            return _bodyStorage.withLockedValue { $0 }
        }
        set {
            _bodyStorage.withLockedValue { $0 = newValue }
        }
    }
    
    /// Get and set `HTTPCookies` for this `HTTPRequest`
    /// This accesses the `"Cookie"` header.
    public var cookies: HTTPCookies {
        get {
            return self.headers.cookie ?? .init()
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

    /// The address from which this HTTP request was received by SwiftNIO.
    /// This address may not represent the original address of the peer, especially if Vapor receives its requests through a reverse-proxy such as nginx.
    public let remoteAddress: SocketAddress?
    
    /// The `EventLoop` which is handling this `Request`. The route handler and any relevant middleware are invoked in this event loop.
    ///
    /// - Warning: A futures-based route handler **MUST** return an `EventLoopFuture` bound to this event loop.
    ///  If this is difficult or awkward to guarantee, use `EventLoopFuture.hop(to:)` to jump to this event loop.
    public let eventLoop: EventLoop
    
    /// A container containing the route parameters that were captured when receiving this request.
    /// Use this container to grab any non-static parameters from the URL, such as model IDs in a REST API.
    public var parameters: Parameters {
        get {
            return _parameters.withLockedValue { $0 }
        }
        set {
            _parameters.withLockedValue { $0 = newValue }
        }
    }

    /// This container is used as arbitrary request-local storage during the request-response lifecycle.Z
    public var storage: Storage {
        get {
            return _storage.withLockedValue { $0 }
        }
        set {
            _storage.withLockedValue { $0 = newValue }
        }
    }

    public let byteBufferAllocator: ByteBufferAllocator
    
    internal let isKeepAlive: NIOLockedValueBox<Bool>
    private let _method: NIOLockedValueBox<HTTPMethod>
    private let _url: NIOLockedValueBox<URI>
    private let _version: NIOLockedValueBox<HTTPVersion>
    private let _headers: NIOLockedValueBox<HTTPHeaders>
    private let _route: NIOLockedValueBox<Route?>
    private let _logger: NIOLockedValueBox<Logger>
    private let _bodyStorage: NIOLockedValueBox<BodyStorage>
    private let _parameters: NIOLockedValueBox<Parameters>
    private let _storage: NIOLockedValueBox<Storage>
    
    // MARK: - Initialisers
    
    public convenience init(
        application: Application,
        method: HTTPMethod = .GET,
        url: URI = "/",
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        collectedBody: ByteBuffer? = nil,
        remoteAddress: SocketAddress? = nil,
        logger: Logger = .init(label: "codes.vapor.request"),
        byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(),
        on eventLoop: EventLoop
    ) {
        self.init(
            application: application,
            method: method,
            url: url,
            version: version,
            headersNoUpdate: headers,
            collectedBody: collectedBody,
            remoteAddress: remoteAddress,
            logger: logger,
            byteBufferAllocator: byteBufferAllocator,
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
        byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(),
        on eventLoop: EventLoop
    ) {
        self.id = UUID().uuidString
        self.application = application
        self._method = .init(method)
        self._url = .init(url)
        self._version = .init(version)
        self._headers = .init(headers)
        if let body = collectedBody {
            self._bodyStorage = .init(.collected(body))
        } else {
            self._bodyStorage = .init(.none)
        }
        self.remoteAddress = remoteAddress
        self.eventLoop = eventLoop
        self._parameters = .init(.init())
        self._storage = .init(.init())
        self.isKeepAlive = .init(true)
        self._logger = .init(logger)
        self.byteBufferAllocator = byteBufferAllocator
        self._route = .init(nil)
        
        self.logger[metadataKey: "request-id"] = .string(id)
    }
}
