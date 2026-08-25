import NIOCore
import NIOFoundationEssentialsCompat
public import HTTPTypes

/// An HTTP response from a server back to the client.
///
///     let res = Response(status: .ok)
///
/// See `HTTPClient`.
public struct Response: CustomStringConvertible, Sendable {
    /// The HTTP response status.
    public var status: HTTPResponse.Status

    /// The header fields for this HTTP response.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPFields
    
    /// The `Body`. Updating this property will also update the associated transport headers.
    ///
    ///     res.body = Response.Body(string: "Hello, world!")
    ///
    /// Also be sure to set this message's `contentType` property to a `MediaType` that correctly
    /// represents the `Body`.
    public var body: Body {
        didSet {
            self.headers.updateContentLength(body.count)
        }
    }

    /// Optional Upgrade behavior to apply to this response.
    /// currently, websocket upgrades are the only defined case.
//    public var upgrader: (any Upgrader)? {
//        get {
//            self.responseBox.withLockedValue { $0.upgrader }
//        }
//        set {
//            self.responseBox.withLockedValue { $0.upgrader = newValue }
//        }
//    }
    
    /// Get and set `HTTPCookies` for this `Response`.
    /// This accesses the `"Set-Cookie"` header.
    public var cookies: HTTPCookies {
        get {
            self.headers.setCookie ?? .init()
        }
        set {
            self.headers.setCookie = newValue
        }
    }
    
    // See `CustomStringConvertible.description`.
    public var description: String {
        var desc: [String] = []
        desc.append("\(status.code) \(status.reasonPhrase)")
        desc.append(self.headers.debugDescription)
        desc.append(self.body.description)
        return desc.joined(separator: "\n")
    }

    // MARK: Content

    private struct _ContentContainer: ContentContainer {
        var response: Response

        var contentConfiguration: ContentConfiguration {
            self.response.contentConfiguration
        }

        var contentType: HTTPMediaType? {
            self.response.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E: Encodable {
            var body = self.response.body.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body, byteBufferAllocator: self.response.body.byteBufferAllocator)
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) throws -> D where D: Decodable {
            guard let body = self.response.body.buffer else {
                throw Abort(.unprocessableContent)
            }
            return try decoder.decode(D.self, from: body, headers: self.response.headers)
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C: Content {
            var content = content
            try content.beforeEncode()
            var body = self.response.body.byteBufferAllocator.buffer(capacity: 0)
            try encoder.encode(content, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body, byteBufferAllocator: self.response.body.byteBufferAllocator)
        }

        func decode<C>(_ content: C.Type, using decoder: any ContentDecoder) throws -> C where C: Content {
            guard let body = self.response.body.buffer else {
                throw Abort(.unprocessableContent)
            }
            var decoded = try decoder.decode(C.self, from: body, headers: self.response.headers)
            try decoded.afterDecode()
            return decoded
        }
    }

    public var content: any ContentContainer {
        get {
            _ContentContainer(response: self)
        }
        set {
            // Write back whatever the container mutated to allow content to be set
            if let container = newValue as? _ContentContainer {
                self = container.response
            }
        }
    }

    /// If `true`, don't serialize the body.
    var forHeadRequest: Bool = false

    private let contentConfiguration: ContentConfiguration

    // MARK: Init
    
    /// Creates a new `Response`.
    ///
    ///     let res = Response(status: .ok)
    ///
    /// - parameters:
    ///     - status: `HTTPResponse.Status` to use. This defaults to `HTTPResponse.Status.ok`
    ///     - headers: `HTTPFields` to include with this response.
    ///                Defaults to empty headers.
    ///                The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically.
    ///     - body: `Body` for this response, defaults to an empty body.
    ///             See `Response.Body` for more information.
    public init(
        status: HTTPResponse.Status = .ok,
        headers: HTTPFields = .init(),
        body: Body = .empty,
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self.init(
            status: status,
            headersNoUpdate: headers,
            body: body,
            contentConfiguration: contentConfiguration
        )
        self.headers.updateContentLength(body.count)
    }

    /// Internal init that creates a new `Response` without sanitizing headers.
    package init(
        status: HTTPResponse.Status,
        headersNoUpdate headers: HTTPFields,
        body: Body,
        contentConfiguration: ContentConfiguration = .default()
    ) {
        self.headers = headers
        self.body = body
        self.contentConfiguration = contentConfiguration
        self.status = status
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
