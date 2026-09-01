#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
#warning("Make this internal")
public import NIOCore
import NIOFoundationEssentialsCompat
public import RoutingKit
import NIOConcurrencyHelpers
public import HTTPTypes
public import X509

/// Represents an HTTP request in an application.
public struct Request: CustomStringConvertible, Sendable {
    public let application: Application

    /// The HTTP method for this request.
    ///
    ///     httpReq.method = .get
    ///
    public let method: HTTPRequest.Method

    /// The URL used on this request.
    public var url: URI

    /// The version for this HTTP request.
    public let version: HTTPVersion

    /// The header fields for this HTTP request.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPFields

    /// A unique ID for the request.
    ///
    /// The request identifier is set to value of the `X-Request-Id` header when present, or to a
    /// uniquely generated value otherwise.
    public let id: String

    // MARK: Metadata

    /// Route object we found for this request.
    /// This holds metadata that can be used for (for example) Metrics.
    ///
    ///     req.route?.description // "GET /hello/:name"
    ///
    public let route: Route?

    /// We try to determine true peer address if load balancer or reversed proxy provided info in headers
    ///
    /// Priority of getting value from headers is as following:
    ///
    /// 1. try the "Forwarded" header (e.g. for=192.0.2.60; proto=http; by=203.0.113.43)
    /// 2. try the "X-Forwarded-For" header (e.g. client_IP, proxy1_IP, proxy2_IP)
    /// 3. fallback to the socket's remote address provided by SwiftNIO ( e.g. 192.0.2.60:62934)
    /// in 1. and 2. will use port 80 as default port, and  3. will have port number provided by NIO if any
    public var peerAddress: SocketAddress? {
        if let clientAddress = headers.forwarded.first?.for {
            try? SocketAddress.init(ipAddress: clientAddress, port: 80)
        } else if let xForwardedFor = headers[.xForwardedFor] {
            try? SocketAddress.init(ipAddress: xForwardedFor, port: 80)
        } else {
            self.remoteAddress
        }
    }

    /// The validated certificate chain. This returns nil if the peer did not authenticate with a certificate. Requires
    /// configuring a `customCertificateVerifyCallbackWithMetadata` that performs the verification.
    public let peerCertificateChain: ValidatedCertificateChain?

    // MARK: Content

    private struct _URLQueryContainer: URLQueryContainer, Sendable {
        var url: URI
        let contentConfiguration: ContentConfiguration

        func decode<D>(_ decodable: D.Type, using decoder: any URLQueryDecoder) throws -> D
            where D: Decodable
        {
            try decoder.decode(D.self, from: self.url)
        }

        mutating func encode(_ encodable: some Encodable, using encoder: any URLQueryEncoder) throws {
            try encoder.encode(encodable, to: &self.url)
        }
    }

    /// This container is used to read and write the request's query string. Changes (e.g. via `req.query.encode`)
    /// are written back to the request
    public var query: any URLQueryContainer {
        get { _URLQueryContainer(url: self.url, contentConfiguration: self.application.contentConfiguration) }
        set { self.url = (newValue as! _URLQueryContainer).url }
    }

    private struct _ContentContainer: ContentContainer, Sendable {
        var body: ByteBuffer?
        var headers: HTTPFields
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            var body = Data()
            try encoder.encode(encodable, to: &body, headers: &self.headers, userInfo: [:])
            self.body = ByteBuffer(data: body)
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) async throws -> D where D : Decodable {
            guard let body = self.body else {
                // This shouldn't be an issue when we support streaming bodies, we should just be able to collect the body
                throw Abort(.unprocessableContent)
            }
            let bodyData = body.getData(at: 0, length: body.readableBytes) ?? Data()
            return try decoder.decode(D.self, from: bodyData, headers: self.headers, userInfo: [:])
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            var body = Data()
            try encoder.encode(content, to: &body, headers: &self.headers, userInfo: [:])
            self.body = ByteBuffer(data: body)
        }
    }

    /// This container is used to read your `Decodable` type using a `ContentDecoder` implementation.
    /// If no `ContentDecoder` is provided, a `Request`'s `Content-Type` header is used to select a registered decoder.
    ///
    /// As with ``query``, the container holds copies of the body and headers and the setter writes
    /// them back, so `req.content.encode(_:)` propagates without relying on that state living behind
    /// a reference.
    public var content: any ContentContainer {
        get {
            _ContentContainer(
                body: self.body.data,
                headers: self.headers,
                contentConfiguration: self.application.contentConfiguration,
            )
        }
        set {
            let container = newValue as! _ContentContainer
            self.headers = container.headers
            self.bodyStorage.withLockedValue { storage in
                storage = container.body.map { .collected($0) } ?? .none
            }
        }
    }

    public var body: Body {
        Body(self)
    }

    internal enum BodyStorage: Sendable {
        case none
        case collected(ByteBuffer)
        case stream(BodyStream)
    }

    /// Get and set `HTTPCookies` for this `Request`
    /// This accesses the `"Cookie"` header.
    public var cookies: HTTPCookies {
        get { self.headers.cookie ?? .init() }
        set { self.headers.cookie = newValue }
    }

    // See `CustomStringConvertible.description`
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

    /// A container containing the route parameters that were captured when receiving this request.
    /// Use this container to grab any non-static parameters from the URL, such as model IDs in a REST API.
    public let parameters: Parameters

    /// Authentication storage for the request
    public let auth: Authentication

    internal let bodyStorage: NIOLockedValueBox<BodyStorage>
    internal let sessionCache: SessionCache

    public init(
        application: Application,
        method: HTTPRequest.Method = .get,
        url: URI = "/",
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPFields = .init(),
        collectedBody: ByteBuffer? = nil,
        remoteAddress: SocketAddress? = nil,
        peerCertificateChain: ValidatedCertificateChain? = nil,
        requestID: String = UUID().uuidString
    ) {
        self.init(
            application: application,
            method: method,
            url: url,
            version: version,
            headersNoUpdate: headers,
            collectedBody: collectedBody,
            remoteAddress: remoteAddress,
            peerCertificateChain: peerCertificateChain,
            requestID: requestID
        )
        if let body = collectedBody {
            self.headers.updateContentLength(body.readableBytes)
        }
    }

    internal init(
        application: Application,
        method: HTTPRequest.Method,
        url: URI,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headersNoUpdate headers: HTTPFields = .init(),
        collectedBody: ByteBuffer? = nil,
        remoteAddress: SocketAddress? = nil,
        peerCertificateChain: ValidatedCertificateChain? = nil,
        requestID: String = UUID().uuidString
    ) {
        let bodyStorage: BodyStorage
        if let body = collectedBody {
            bodyStorage = .collected(body)
        } else {
            bodyStorage = .none
        }

        self.id = requestID
        self.application = application

        self.remoteAddress = remoteAddress
        self.bodyStorage = .init(bodyStorage)
        self.auth = Authentication()
        self.sessionCache = SessionCache()

        self.method = method
        self.peerCertificateChain = peerCertificateChain
        self.version = version
        self.route = nil
        self.parameters = .init()
        self.url = url
        self.headers = headers
    }

    package init(_ other: Request, route: Route?, parameters: Parameters) {
        self.application = other.application
        self.method = other.method
        self.version = other.version
        self.id = other.id
        self.remoteAddress = other.remoteAddress
        self.peerCertificateChain = other.peerCertificateChain
        self.auth = other.auth
        self.sessionCache = other.sessionCache
        self.bodyStorage = other.bodyStorage
        self.route = route
        self.parameters = parameters
        self.url = other.url
        self.headers = other.headers
    }
}
