#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
#warning("Make this internal")
public import NIOCore
import NIOFoundationEssentialsCompat
import NIOHTTP1
import Logging
public import RoutingKit
import NIOConcurrencyHelpers
public import HTTPTypes
import NIOPosix
import ServiceContextModule
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
    public var url: URI {
        get { self.requestBox.withLockedValue { $0.url } }
        set { self.requestBox.withLockedValue { $0.url = newValue } }
    }

    /// The version for this HTTP request.
    public let version: HTTPVersion

    /// The header fields for this HTTP request.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPFields {
        get { self.requestBox.withLockedValue { $0.headers } }
        set { self.requestBox.withLockedValue { $0.headers = newValue } }
    }

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
    public var route: Route? {
        get { self.requestBox.withLockedValue { $0.route } }
        set { self.requestBox.withLockedValue { $0.route = newValue } }
    }

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
        var request: Request
        let contentConfiguration: ContentConfiguration

        func decode<D>(_ decodable: D.Type, using decoder: any URLQueryDecoder) throws -> D
            where D: Decodable
        {
            try decoder.decode(D.self, from: self.request.url)
        }

        mutating func encode(_ encodable: some Encodable, using encoder: any URLQueryEncoder) throws {
            try encoder.encode(encodable, to: &self.request.url)
        }
    }

    public var query: any URLQueryContainer {
        get { _URLQueryContainer(request: self, contentConfiguration: self.application.contentConfiguration) }
        set { } // ignore since Request is a reference type
    }

    private struct _ContentContainer: ContentContainer, Sendable {
        var request: Request

        var contentType: HTTPMediaType? {
            self.request.headers.contentType
        }

        var contentConfiguration: ContentConfiguration {
            self.request.application.contentConfiguration
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            var body = Data()
            try encoder.encode(encodable, to: &body, headers: &self.request.headers, userInfo: [:])
            let byteBuffer = ByteBuffer(data: body)
            self.request.bodyStorage.withLockedValue { $0 = .collected(byteBuffer) }
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) async throws -> D where D : Decodable {
            if let stream = self.request.streamBodyStorage.withLockedValue({ $0 }) {
                let buffer = try await self.request.collectStream(stream, maxSize: request.application.routes.defaultMaxBodySize.value)
                let bufferData = buffer.getData(at: 0, length: buffer.readableBytes) ?? Data()
                return try decoder.decode(D.self, from: bufferData, headers: self.request.headers, userInfo: [:])
            }
            guard let body = self.request.body.data else {
                Logger.current.debug("Request body is empty. If you're trying to stream the body, decoding streaming bodies not supported")
                throw Abort(.unprocessableContent)
            }
            let bodyData = body.getData(at: 0, length: body.readableBytes) ?? Data()
            return try decoder.decode(D.self, from: bodyData, headers: self.request.headers, userInfo: [:])
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            var body = Data()
            try encoder.encode(content, to: &body, headers: &self.request.headers, userInfo: [:])
            let byteBuffer = ByteBuffer(data: body)
            self.request.bodyStorage.withLockedValue { $0 = .collected(byteBuffer) }
        }
    }

    /// This container is used to read your `Decodable` type using a `ContentDecoder` implementation.
    /// If no `ContentDecoder` is provided, a `Request`'s `Content-Type` header is used to select a registered decoder.
    public var content: any ContentContainer {
        get { _ContentContainer(request: self) }
        set { } // ignore since Request is a reference type
    }

    public var body: Body {
        Body(self)
    }

    public var newBody: NewBody {
        NewBody(underlying: self.streamBodyStorage.withLockedValue({ $0 }), maxBodySize: 16*1024)
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
    public var parameters: Parameters {
        get { self.requestBox.withLockedValue { $0.parameters } }
        set { self.requestBox.withLockedValue { $0.parameters = newValue } }
    }

    /// Authentication storage for the request
    public let auth: Authentication

    struct RequestBox: Sendable {
        var url: URI
        var headers: HTTPFields
        var route: Route?
        var parameters: Parameters
    }

    let requestBox: NIOLockedValueBox<RequestBox>

    internal let bodyStorage: NIOLockedValueBox<BodyStorage>
    internal let streamBodyStorage: NIOLockedValueBox<AsyncStream<ByteBuffer>?>
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

        let storageBox = RequestBox(
            url: url,
            headers: headers,
            route: nil,
            parameters: .init(),
        )
        self.requestBox = .init(storageBox)
        self.id = requestID
        self.application = application

        self.remoteAddress = remoteAddress
        self.bodyStorage = .init(bodyStorage)
        self.streamBodyStorage = .init(nil)
        self.auth = Authentication()
        self.sessionCache = SessionCache()

        self.method = method
        self.peerCertificateChain = peerCertificateChain
        self.version = version
    }

    internal func collectStream(_ stream: AsyncStream<ByteBuffer>, maxSize: Int) async throws -> ByteBuffer {
        var collected = ByteBuffer()
        for await var chunk in stream {
            collected.writeBuffer(&chunk)
            guard collected.readableBytes <= maxSize else {
                throw Abort(.contentTooLarge)
            }
        }
        return collected
    }
}
