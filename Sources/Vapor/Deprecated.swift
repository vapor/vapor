extension HTTPServer.Configuration {
    /// When `true`, HTTP server will support gzip and deflate compression.
    @available(*, deprecated, message: "Use requestDecompression and responseCompression")
    public var supportCompression: Bool {
        get {
            switch (self.requestDecompression.storage, self.responseCompression.storage) {
            case (.enabled, .enabled):
                return true
            default:
                return false
            }
        }
        set {
            self.requestDecompression = .enabled
            self.responseCompression = .enabled
        }
    }

    /// Limit of data to decompress when HTTP compression is supported.
    @available(*, deprecated, message: "Use requestDecompression")
    public var decompressionLimit: NIOHTTPDecompression.DecompressionLimit {
        get {
            switch self.requestDecompression.storage {
            case .disabled:
                return .ratio(10)
            case .enabled(let limit):
                return limit
            }
        }
        set {
            self.requestDecompression = .enabled(limit: newValue)
        }
    }

    @available(*, deprecated, message: "Use requestDecompression and responseCompression")
    public init(
        hostname: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        maxBodySize: Int = 1 << 14,
        reuseAddress: Bool = true,
        tcpNoDelay: Bool = true,
        webSocketMaxFrameSize: Int = 1 << 14,
        supportCompression: Bool = false,
        decompressionLimit: NIOHTTPDecompression.DecompressionLimit = .ratio(10),
        supportPipelining: Bool = false,
        supportVersions: Set<HTTPVersionMajor>? = nil,
        tlsConfiguration: TLSConfiguration? = nil,
        serverName: String? = nil,
        logger: Logger? = nil
    ) {
        self.init(
            hostname: hostname,
            port: port,
            backlog: backlog,
            maxBodySize: maxBodySize,
            reuseAddress: reuseAddress,
            tcpNoDelay: tcpNoDelay,
            webSocketMaxFrameSize: webSocketMaxFrameSize,
            responseCompression: supportCompression
                ? .enabled : .disabled,
            requestDecompression: supportCompression
                ? .enabled(limit: decompressionLimit) : .disabled,
            supportPipelining: supportPipelining,
            supportVersions: supportVersions,
            tlsConfiguration: tlsConfiguration,
            serverName: serverName,
            logger: logger
        )
    }
}

extension Application {
    private struct UserInfoKey: StorageKey {
        typealias Value = [AnyHashable: Any]
    }

    @available(*, deprecated, message: "Use storage instead.")
    public var userInfo: [AnyHashable: Any] {
        get {
            self.storage[UserInfoKey.self] ?? [:]
        }
        set {
            self.storage[UserInfoKey.self] = newValue
        }
    }
}

extension Request {
    private struct UserInfoKey: StorageKey {
        typealias Value = [AnyHashable: Any]
    }

    @available(*, deprecated, message: "Use storage instead.")
    public var userInfo: [AnyHashable: Any] {
        get {
            self.storage[UserInfoKey.self] ?? [:]
        }
        set {
            self.storage[UserInfoKey.self] = newValue
        }
    }
}

extension HTTPHeaders {
    @available(*, deprecated, renamed: "first")
    public func firstValue(name: Name) -> String? {
        // fixme: optimize
        return self[name.lowercased].first
    }
}

/// Represents a header value with optional parameter metadata.
///
/// Parses a header string like `application/json; charset="utf8"`, into:
///
/// - value: `"application/json"`
/// - parameters: ["charset": "utf8"]
///
/// Simplified format:
///
///     headervalue := value *(";" parameter)
///     ; Matching of media type and subtype
///     ; is ALWAYS case-insensitive.
///
///     value := token
///
///     parameter := attribute "=" value
///
///     attribute := token
///     ; Matching of attributes
///     ; is ALWAYS case-insensitive.
///
///     token := 1*<any (US-ASCII) CHAR except SPACE, CTLs,
///         or tspecials>
///
///     value := token
///     ; token MAY be quoted
///
///     tspecials :=  "(" / ")" / "<" / ">" / "@" /
///                   "," / ";" / ":" / "\" / <">
///                   "/" / "[" / "]" / "?" / "="
///     ; Must be in quoted-string,
///     ; to use within parameter values
@available(*, deprecated)
public struct HTTPHeaderValue: Codable {
    /// The `HeaderValue`'s main value.
    ///
    /// In the `HeaderValue` `"application/json; charset=utf8"`:
    ///
    /// - value: `"application/json"`
    public var value: String

    /// The `HeaderValue`'s metadata. Zero or more key/value pairs.
    ///
    /// In the `HeaderValue` `"application/json; charset=utf8"`:
    ///
    /// - parameters: ["charset": "utf8"]
    public var parameters: [String: String]

    /// Creates a new `HeaderValue`.
    public init(_ value: String, parameters: [String: String] = [:]) {
        self.value = value
        self.parameters = parameters
    }

    /// Initialize a `HTTPHeaderValue` from a Decoder.
    ///
    /// This will decode a `String` from the decoder and parse it to a `HTTPHeaderValue`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let tempValue = HTTPHeaderValue.parse(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid header value string")
        }
        self.parameters = tempValue.parameters
        self.value = tempValue.value
    }

    /// Encode a `HTTPHeaderValue` into an Encoder.
    ///
    /// This will encode the `HTTPHeaderValue` as a `String`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.serialize())
    }

    /// Serializes this `HeaderValue` to a `String`.
    public func serialize() -> String {
        var string = "\(self.value)"
        for (key, val) in self.parameters {
            string += "; \(key)=\"\(val)\""
        }
        return string
    }

    /// Parse a `HeaderValue` from a `String`.
    ///
    ///     guard let headerValue = HTTPHeaderValue.parse("application/json; charset=utf8") else { ... }
    ///
    public static func parse(_ data: String) -> HTTPHeaderValue? {
        fatalError()
//        var parser = HTTPHeaders.ValueParser(string: data)
//        guard let value = parser.nextValue() else {
//            return nil
//        }
//        var parameters: [String: String] = [:]
//        while let (key, value) = parser.nextParameter() {
//            parameters[.init(key)] = .init(value)
//        }
//        return .init(.init(value), parameters: parameters)
    }
}
