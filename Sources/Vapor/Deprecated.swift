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
