import NIO
import NIOHTTP1
import NIOFoundationCompat

/// An HTTP response from a server back to the client.
///
///     let httpRes = HTTPResponse(status: .ok)
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
    
    /// The `HTTPBody`. Updating this property will also update the associated transport headers.
    ///
    ///     httpRes.body = HTTPBody(string: "Hello, world!")
    ///
    /// Also be sure to set this message's `contentType` property to a `MediaType` that correctly
    /// represents the `HTTPBody`.
    public var body: Body {
        didSet { self.headers.updateContentLength(self.body.count) }
    }

    internal enum Upgrader {
        case webSocket(maxFrameSize: WebSocketMaxFrameSize, onUpgrade: (WebSocket) -> ())
    }
    
    internal var upgrader: Upgrader?

    public var storage: Storage
    
    /// Get and set `HTTPCookies` for this `HTTPResponse`
    /// This accesses the `"Set-Cookie"` header.
    public var cookies: HTTPCookies {
        get {
            return self.headers.setCookie
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
            var body = ByteBufferAllocator().buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.response.headers)
            self.response.body = .init(buffer: body)
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.response.body.buffer else {
                throw Abort(.unprocessableEntity)
            }
            return try decoder.decode(D.self, from: body, headers: self.response.headers)
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
    
    // MARK: Init
    
    /// Creates a new `HTTPResponse`.
    ///
    ///     let httpRes = HTTPResponse(status: .ok)
    ///
    /// - parameters:
    ///     - status: `HTTPResponseStatus` to use. This defaults to `HTTPResponseStatus.ok`
    ///     - version: `HTTPVersion` of this response, should usually be (and defaults to) 1.1.
    ///     - headers: `HTTPHeaders` to include with this response.
    ///                Defaults to empty headers.
    ///                The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically.
    ///     - body: `HTTPBody` for this response, defaults to an empty body.
    ///             See `LosslessHTTPBodyRepresentable` for more information.
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
    
    
    /// Internal init that creates a new `HTTPResponse` without sanitizing headers.
    public init(
        status: HTTPResponseStatus,
        version: HTTPVersion,
        headersNoUpdate headers: HTTPHeaders,
        body: Body
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
        self.storage = .init()
    }

    /// Creates a `Response` which includes an `ETag` HTTP header.
    ///
    ///  The `withBody` parameter is here so that you can determine, based on client preference,
    ///  whether or not to include the response body when performing a `PATCH` call, for example.
    ///  You want the `ETag` header to be included, but you may or may not want the body.
    ///
    ///  If you want to support returning a status code of 304 (Not Modified) based on a matching
    ///  HTTP `If-None-Match` header, you can pass in the `req` parameter to be examined.
    ///
    /// - Parameters:
    ///   - obj: The object which is (possibly) being encoded and used to calculate the ETag
    ///   - includeBody: Whether or not the `obj` should be included in the body.
    ///   - justCreated: Whether this is a newly created object or not. Determines 201 vs. 200 status
    ///   - req: The `Request` to examine for an `If-None-Match` header.
    /// - Throws: If the encoding fails, or the ETag can't be generated.
    /// - Returns: A `Response`
    public static func withETag<T>(
        _ obj: T,
        includeBody: Bool = true,
        justCreated: Bool = false,
        req: Request? = nil
    ) throws -> Response where T: Content {
        let status: HTTPStatus
        if justCreated {
            status = .created
        } else if includeBody {
            status = .ok
        } else {
            status = .noContent
        }

        let response = Response(status: status)

        if let eTag = try obj.eTag(), !eTag.isEmpty {
            if let req = req, let ifNoneMatchHeaders = req.headers.first(name: .ifNoneMatch) {
                var cs = CharacterSet.whitespacesAndNewlines
                cs.insert(",")

                let comparisons = ifNoneMatchHeaders
                    .components(separatedBy: cs)
                    .filter { !$0.isEmpty }

                for comparison in comparisons {
                    if eTag == comparison {
                        response.status = .notModified
                        return response
                    }
                }
            }

            response.headers.add(name: .eTag, value: eTag)
        }

        if includeBody {
            try response.content.encode(obj)
        }

        return response
    }
}


extension HTTPHeaders {
    mutating func updateContentLength(_ contentLength: Int) {
        let count = contentLength.description
        self.remove(name: .transferEncoding)
        if count != self[.contentLength].first {
            self.replaceOrAdd(name: .contentLength, value: count)
        }
    }
}
