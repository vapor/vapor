import NIOCore
import NIOHTTP1
import NIOFoundationCompat
import NIOConcurrencyHelpers
import HTTPTypes

/// An HTTP response from a server back to the client.
///
///     let res = Response(status: .ok)
///
/// See `HTTPClient` and `HTTPServerOld`.
public final class Response: CustomStringConvertible, Sendable {
    /// Maximum streaming body size to use for `debugPrint(_:)`.
    private let maxDebugStreamingBodySize: Int = 1_000_000

    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion {
        get {
            self.responseBox.withLockedValue { $0.version }
        }
        set {
            self.responseBox.withLockedValue { $0.version = newValue }
        }
    }
    
    /// The HTTP response status.
    public var status: HTTPResponse.Status {
        get {
            self.responseBox.withLockedValue { $0.status }
        }
        set {
            self.responseBox.withLockedValue { $0.status = newValue }
        }
    }
    
    /// The header fields for this HTTP response.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPFields {
        get {
            self.responseBox.withLockedValue { $0.headers }
        }
        set {
            self.responseBox.withLockedValue { $0.headers = newValue }
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
            responseBox.withLockedValue { $0.body }
        }
        set {
            responseBox.withLockedValue { box in
                box.body = newValue
            }
        }
    }

    /// Optional Upgrade behavior to apply to this response.
    /// currently, websocket upgrades are the only defined case.
    public var upgrader: (any Upgrader)? {
        get {
            self.responseBox.withLockedValue { $0.upgrader }
        }
        set {
            self.responseBox.withLockedValue { $0.upgrader = newValue }
        }
    }

    public var storage: Storage {
        get {
            self._storage.withLockedValue { $0 }
        }
        set {
            self._storage.withLockedValue { $0 = newValue }
        }
    }
    
    /// Get and set `HTTPCookies` for this `Response`.
    /// This accesses the `"Set-Cookie"` header.
    public var cookies: HTTPCookies {
        get {
            return self.responseBox.withLockedValue { box in
                box.headers.setCookie ?? .init()
            }
        }
        set {
            self.responseBox.withLockedValue { box in
                box.headers.setCookie = newValue
            }
        }
    }
    
    // See `CustomStringConvertible.description`.
    public var description: String {
        var desc: [String] = []
        self.responseBox.withLockedValue { box in
            desc.append("HTTP/\(box.version.major).\(box.version.minor) \(box.status.code) \(box.status.reasonPhrase)")
            desc.append(box.headers.debugDescription)
            desc.append(box.body.description)
        }
        return desc.joined(separator: "\n")
    }

    // MARK: Content

    private struct _ContentContainer: ContentContainer {
        let response: Response

        var contentConfiguration: ContentConfiguration {
            self.response.contentConfiguration
        }

        var contentType: HTTPMediaType? {
            return self.response.headers.contentType
        }

        func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            try self.response.responseBox.withLockedValue { box in
                var body = box.body.byteBufferAllocator.buffer(capacity: 0)
                try encoder.encode(encodable, to: &body, headers: &box.headers)
                box.body = .init(buffer: body, byteBufferAllocator: box.body.byteBufferAllocator)
            }
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) throws -> D where D : Decodable {
            try self.response.responseBox.withLockedValue { box in
                guard let body = box.body.buffer else {
                    throw Abort(.unprocessableContent)
                }
                return try decoder.decode(D.self, from: body, headers: box.headers)
            }
        }

        func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            try self.response.responseBox.withLockedValue { box in
                var body = box.body.byteBufferAllocator.buffer(capacity: 0)
                try encoder.encode(content, to: &body, headers: &box.headers)
                box.body = .init(buffer: body, byteBufferAllocator: box.body.byteBufferAllocator)
            }
        }

        func decode<C>(_ content: C.Type, using decoder: any ContentDecoder) throws -> C where C : Content {
            var decoded = try self.response.responseBox.withLockedValue { box in
                guard let body = box.body.buffer else {
                    throw Abort(.unprocessableContent)
                }
                return try decoder.decode(C.self, from: body, headers: box.headers)
            }
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: any ContentContainer {
        get {
            return _ContentContainer(response: self)
        }
        set {
            // ignore since Request is a reference type
        }
    }
    
    struct ResponseBox: Sendable {
        var version: HTTPVersion
        var status: HTTPResponse.Status
        var headers: HTTPFields
        var body: Body {
            didSet {
                self.headers.updateContentLength(body.count)
            }
        }
        var upgrader: (any Upgrader)?
        // If `true`, don't serialize the body.
        var forHeadRequest: Bool

    }
    
    let responseBox: NIOLockedValueBox<ResponseBox>
    private let _storage: NIOLockedValueBox<Storage>
    private let contentConfiguration: ContentConfiguration

    // MARK: Init
    
    /// Creates a new `Response`.
    ///
    ///     let res = Response(status: .ok)
    ///
    /// - parameters:
    ///     - status: `HTTPResponse.Status` to use. This defaults to `HTTPResponse.Status.ok`
    ///     - version: `HTTPVersion` of this response, should usually be (and defaults to) 1.1.
    ///     - headers: `HTTPFields` to include with this response.
    ///                Defaults to empty headers.
    ///                The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically.
    ///     - body: `Body` for this response, defaults to an empty body.
    ///             See `Response.Body` for more information.
    public convenience init(
        status: HTTPResponse.Status = .ok,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPFields = .init(),
        body: Body = .empty,
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self.init(
            status: status,
            version: version,
            headersNoUpdate: headers,
            body: body,
            contentConfiguration: contentConfiguration
        )
        self.headers.updateContentLength(body.count)
    }

    /// Internal init that creates a new `Response` without sanitizing headers.
    public init(
        status: HTTPResponse.Status,
        version: HTTPVersion,
        headersNoUpdate headers: HTTPFields,
        body: Body,
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self._storage = .init(.init())
        self.responseBox = .init(.init(version: version, status: status, headers: headers, body: body, forHeadRequest: false))
        self.contentConfiguration = contentConfiguration
    }
}


extension HTTPFields {
    mutating func updateContentLength(_ contentLength: Int) {
        let count = contentLength.description
        switch contentLength {
        case -1:
            self[.contentLength] = nil
            if "chunked" != self[.transferEncoding] {
                self[.transferEncoding] = "chunked"
            }
        default:
            self[.transferEncoding] = nil
            if count != self[.contentLength] {
                self[.contentLength] = count
            }
        }
    }
}
