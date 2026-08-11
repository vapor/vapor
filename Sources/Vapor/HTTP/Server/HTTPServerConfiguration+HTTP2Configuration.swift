extension ServerConfiguration {
    /// HTTP/2 specific configuration.
    ///
    /// HTTP/2 is only negotiated over TLS (via ALPN). Adding an ``ServerConfiguration/HTTPVersion/http2(config:)``
    /// version without also setting ``ServerConfiguration/tlsConfiguration`` will cause the server to fail to start.
    public struct HTTP2: Sendable, Hashable {
        /// The maximum frame size to be used in an HTTP/2 connection.
        public var maxFrameSize: Int

        /// The target window size for the connection.
        ///
        /// - Note: This is also used as the initial window size for the connection.
        public var targetWindowSize: Int

        /// The maximum number of concurrent streams permitted on the connection.
        public var maxConcurrentStreams: Int

        /// The graceful shutdown configuration.
        public var gracefulShutdown: GracefulShutdownConfiguration

        /// Configuration options for HTTP/2 graceful shutdown behavior.
        public struct GracefulShutdownConfiguration: Sendable, Hashable {
            /// The maximum amount of time that the connection has to close gracefully.
            ///
            /// When `nil`, no time limit is enforced on the graceful shutdown process.
            public var maximumGracefulShutdownDuration: Duration?

            /// Creates a graceful shutdown configuration.
            ///
            /// - Parameter maximumGracefulShutdownDuration: The maximum amount of time the connection has to close
            ///   gracefully. When `nil`, no time limit is enforced.
            public init(maximumGracefulShutdownDuration: Duration? = nil) {
                self.maximumGracefulShutdownDuration = maximumGracefulShutdownDuration
            }
        }

        /// Creates a new HTTP/2 configuration.
        ///
        /// - Parameters:
        ///   - maxFrameSize: The maximum frame size to be used in a connection. Defaults to `2^14`.
        ///   - targetWindowSize: The target window size for a connection, also used as the initial window size.
        ///     Defaults to `2^16 - 1`.
        ///   - maxConcurrentStreams: The maximum number of concurrent streams permitted. Defaults to `100`.
        ///   - gracefulShutdown: The graceful shutdown configuration.
        public init(
            maxFrameSize: Int = Self.defaultMaxFrameSize,
            targetWindowSize: Int = Self.defaultTargetWindowSize,
            maxConcurrentStreams: Int = Self.defaultMaxConcurrentStreams,
            gracefulShutdown: GracefulShutdownConfiguration = .init()
        ) {
            self.maxFrameSize = maxFrameSize
            self.targetWindowSize = targetWindowSize
            self.maxConcurrentStreams = maxConcurrentStreams
            self.gracefulShutdown = gracefulShutdown
        }

        @inlinable
        static var defaultMaxFrameSize: Int { 1 << 14 }

        @inlinable
        static var defaultTargetWindowSize: Int { (1 << 16) - 1 }

        @inlinable
        static var defaultMaxConcurrentStreams: Int { 100 }

        /// The default HTTP/2 configuration.
        ///
        /// The max frame size defaults to `2^14`, the target window size to `2^16 - 1`, and the max concurrent
        /// streams to `100`.
        public static var defaults: Self {
            Self(
                maxFrameSize: Self.defaultMaxFrameSize,
                targetWindowSize: Self.defaultTargetWindowSize,
                maxConcurrentStreams: Self.defaultMaxConcurrentStreams,
                gracefulShutdown: GracefulShutdownConfiguration()
            )
        }
    }

    /// An HTTP protocol version the server can advertise and serve.
    ///
    /// Use ``http1_1`` and ``http2(config:)`` to build the set passed to ``ServerConfiguration/httpVersions``.
    public struct HTTPVersion: Sendable, Hashable {
        /// The underlying protocol version, carrying the HTTP/2 configuration when applicable.
        enum Version: Sendable, Hashable {
            case http1_1
            case http2(config: HTTP2)

            var http2Config: HTTP2? {
                switch self {
                case .http1_1:
                    return nil
                case .http2(let config):
                    return config
                }
            }
        }

        var version: Version

        /// The HTTP/1.1 protocol version.
        public static var http1_1: Self {
            Self.init(version: .http1_1)
        }

        /// The HTTP/2 protocol version.
        ///
        /// - Parameter config: The configuration to use for HTTP/2 connections.
        public static func http2(config: HTTP2) -> Self {
            Self.init(version: .http2(config: config))
        }

        /// Two values are equal if they represent the same protocol version, regardless of any differences in the
        /// HTTP/2 configuration.
        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs.version, rhs.version) {
            case (.http1_1, .http1_1), (.http2, .http2):
                return true

            default:
                return false
            }
        }

        /// Hashes by protocol version only, consistent with the `Equatable` conformance.
        public func hash(into hasher: inout Hasher) {
            switch self.version {
            case .http1_1:
                hasher.combine(1)

            case .http2:
                hasher.combine(2)
            }
        }
    }
}
