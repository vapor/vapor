extension ServerConfiguration {
    /// Configuration for HTTP/3.
    ///
    ///
    /// HTTP/3 requires TLS.
    /// If a ``ServerConfiguration/HTTPVersion/http3(config:)`` version is added to ``ServerConfiguration/httpVersions``
    /// without also setting a ``ServerConfiguration/tlsConfiguration``,
    /// the server throws an error when it starts (rather than serving over plaintext),
    /// so callers can catch it and decide how to handle it.
    public struct HTTP3: Sendable, Hashable {
        /// If true, Huffman encoding will be used where applicable, e.g. for header field sections.
        ///
        /// - Note: Huffman encoding will not be used if it would result in a larger payload than not using it, even if
        ///   this property is true.
        public var preferHuffmanEncoding = true

        /// QUIC transport configuration.
        public var quicConfiguration: QUICConfiguration = .defaults

        /// HTTP/3 connection settings exchanged with the client during connection establishment.
        public var connectionSettings: ConnectionSettings = .defaults

        /// Creates an HTTP/3 configuration.
        ///
        /// - Parameters:
        ///   - preferHuffmanEncoding: Whether Huffman encoding is used where applicable.
        ///   - quicConfiguration: QUIC transport parameters.
        ///   - connectionSettings: HTTP/3 connection-level settings exchanged with the client.
        public init(
            preferHuffmanEncoding: Bool,
            quicConfiguration: QUICConfiguration,
            connectionSettings: ConnectionSettings,
        ) {
            self.preferHuffmanEncoding = preferHuffmanEncoding
            self.quicConfiguration = quicConfiguration
            self.connectionSettings = connectionSettings
        }

        /// The default HTTP/3 configuration.
        ///
        /// Uses the default configurations of the sub-components:
        /// - `preferHuffmanEncoding`: `true`.
        /// - `quicConfiguration`: ``QUICConfiguration/defaults``.
        /// - `connectionSettings`: ``ConnectionSettings/defaults``.
        /// - `datagramConfiguration`: ``DatagramConfiguration/defaults``.
        public static var defaults: Self {
            Self(
                preferHuffmanEncoding: true,
                quicConfiguration: .defaults,
                connectionSettings: .defaults
            )
        }
    }
}

extension ServerConfiguration.HTTP3 {
    /// QUIC transport configuration for an HTTP/3 server.
    public struct QUICConfiguration: Sendable, Hashable {
        /// Configuration for writing qlog files, which capture QUIC and HTTP/3 events for debugging and analysis.
        ///
        /// - SeeAlso: https://www.ietf.org/archive/id/draft-ietf-quic-qlog-main-schema-13.html
        public struct QLogConfiguration: Sendable, Hashable {
            /// The directory to where the qlog files are written to.
            public var path: String

            /// The title to use when logging.
            public var topic: String

            /// The description to use when logging.
            public var description: String

            /// Creates a qlog configuration with the given directory, topic, and description.
            ///
            /// - Parameters:
            ///   - path: The directory to write qlog files to.
            ///   - topic: The title to use when logging.
            ///   - description: The description to use when logging.
            public init(path: String, topic: String, description: String) {
                self.path = path
                self.topic = topic
                self.description = description
            }
        }

        /// The TLS 1.3 key exchange named group.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc8446#section-4.2.7 and
        ///   https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-8
        public struct KeyExchangeGroup: Sendable, Hashable {
            enum Backing: UInt16 {
                case secp256 = 0x0017
                case secp384 = 0x0018
                case x25519 = 0x001D
                case x25519MLKEM768 = 0x11EC
            }

            let backing: Backing

            /// The NIST P-256 elliptic curve.
            public static var secp256: Self {
                .init(backing: .secp256)
            }

            /// The NIST P-384 elliptic curve.
            public static var secp384: Self {
                .init(backing: .secp384)
            }

            /// The X25519 elliptic curve (Curve25519).
            public static var x25519: Self {
                .init(backing: .x25519)
            }

            /// A post-quantum hybrid group that combines X25519 with the ML-KEM-768 key encapsulation mechanism.
            public static var x25519MLKEM768: Self {
                .init(backing: .x25519MLKEM768)
            }
        }

        /// The server's hostname for the TLS handshake.
        ///
        /// - Important: SwiftTLS currently just ignores the server name sent in the ClientHello. See
        ///   https://github.com/apple/swift-nio-quic/issues/4.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc6066#section-3
        public var serverName: String

        /// The named group to use for the TLS 1.3 key exchange.
        public var keyExchangeGroup: KeyExchangeGroup

        /// The idle timeout advertised to the client. A connection may time out sooner than this value if the client
        /// advertises a shorter idle timeout.
        ///
        /// - Important: The effective idle timeout enforced on a connection is the minimum of both endpoints'
        ///   advertised values.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.4.1 and
        ///   https://datatracker.ietf.org/doc/html/rfc9000#name-idle-timeout
        public var maxIdleTimeout: Duration

        /// The initial value for the maximum amount of data (in bytes) that can be sent on the connection.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.14.1
        public var initialMaxData: Int

        /// The initial flow control limit for locally initiated bidirectional streams.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.16.1
        public var initialMaxStreamDataBidirectionalLocal: Int

        /// The initial flow control limit for client-initiated bidirectional streams.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.18.1
        public var initialMaxStreamDataBidirectionalRemote: Int

        /// The initial flow control limit for unidirectional streams.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.20.1
        public var initialMaxStreamDataUnidirectional: Int

        /// The initial maximum number of bidirectional streams the server is permitted to initiate.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.22.1
        public var initialMaxStreamsBidirectional: Int

        /// The initial maximum number of unidirectional streams the server is permitted to initiate.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-18.2-4.24.1
        public var initialMaxStreamsUnidirectional: Int

        /// The interval at which the server sends keep-alive PING frames.
        ///
        /// Each PING restarts both endpoints' idle timers. The server's idle timer is restarted when the PING is sent,
        /// and the peer's idle timer is restarted when the PING is received. This prevents the connection from being
        /// closed by ``maxIdleTimeout``.
        ///
        /// - Important: For keep-alive pings to be effective, the interval must be shorter than the negotiated idle
        ///   timeout.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-10.1.2
        public var keepAliveInterval: Duration?

        /// Whether the server sends a Retry packet before accepting a new connection.
        ///
        /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc9000#section-8.1.2
        public var sendRetry: Bool

        /// The path to a file where TLS session keys are logged in NSS Key Log format.
        ///
        /// When set, tools such as Wireshark can use this file to decrypt captured QUIC traffic.
        public var keyLogPath: String?

        /// Optional qlog configuration.
        ///
        /// When set, QUIC and HTTP/3 events are written to qlog files in the specified directory, which is useful for
        /// debugging and analysis.
        public var qLogConfiguration: QLogConfiguration?

        /// The default QUIC transport configuration.
        ///
        /// Uses the following default values:
        /// - `keyExchangeGroup`: ``KeyExchangeGroup/x25519``.
        /// - `maxIdleTimeout`: 30 seconds.
        /// - `initialMaxData`: 1 MiB.
        /// - `initialMaxStreamDataBidirectionalLocal`: 1 MiB.
        /// - `initialMaxStreamDataBidirectionalRemote`: 1 MiB.
        /// - `initialMaxStreamDataUnidirectional`: 1 MiB.
        /// - `initialMaxStreamsBidirectional`: 100 streams.
        /// - `initialMaxStreamsUnidirectional`: 100 streams.
        /// - `keepAliveInterval`: `nil` (no keep-alive PINGs are sent).
        /// - `sendRetry`: `false`.
        /// - `keyLogPath`: `nil` (TLS session keys are not logged).
        /// - `qLogConfiguration`: `nil` (qlog is not enabled).
        public static var defaults: Self {
            Self(
                // SwiftTLS currently just ignores the `serverName` sent in the ClientHello. This default configuration
                // just sets `serverName` to an empty string. See https://github.com/apple/swift-nio-quic/issues/4.
                serverName: "",
                keyExchangeGroup: .x25519,
                maxIdleTimeout: .seconds(30),
                initialMaxData: 1024 * 1024,
                initialMaxStreamDataBidirectionalLocal: 1024 * 1024,
                initialMaxStreamDataBidirectionalRemote: 1024 * 1024,
                initialMaxStreamDataUnidirectional: 1024 * 1024,
                initialMaxStreamsBidirectional: 100,
                initialMaxStreamsUnidirectional: 100,
                keepAliveInterval: nil,
                sendRetry: false,
                keyLogPath: nil,
                qLogConfiguration: nil
            )
        }
    }
}

extension ServerConfiguration.HTTP3 {
    /// HTTP/3 connection settings sent to the peer during connection establishment.
    public struct ConnectionSettings: Sendable, Hashable {
        /// The maximum capacity of the QPACK dynamic table.
        ///
        /// - SeeAlso: https://www.rfc-editor.org/rfc/rfc9204.html#section-5-2.2.1. Corresponds to
        ///   `SETTINGS_QPACK_MAX_TABLE_CAPACITY`.
        public var qpackMaximumTableCapacity: UInt64

        /// The maximum number of streams which may be blocked on QPACK at any one time.
        ///
        /// - SeeAlso: https://www.rfc-editor.org/rfc/rfc9204.html#section-5-2.4.1. Corresponds to
        ///   `SETTINGS_QPACK_BLOCKED_STREAMS`.
        public var qpackBlockedStreams: UInt64

        /// The maximum size of a field section.
        ///
        /// - SeeAlso: https://www.rfc-editor.org/rfc/rfc9114.html#section-7.2.4.1-2.2.1. Corresponds to
        ///   `SETTINGS_MAX_FIELD_SECTION_SIZE`.
        public var maximumFieldSectionSize: UInt64?

        /// The default HTTP/3 connection settings configuration.
        ///
        /// Uses the following default values:
        /// - `qpackMaximumTableCapacity`: 0
        /// - `qpackBlockedStreams`: 0
        /// - `maximumFieldSectionSize`: `nil` (no field section size limit)
        public static var defaults: Self {
            Self(
                qpackMaximumTableCapacity: 0,
                qpackBlockedStreams: 0,
                maximumFieldSectionSize: nil
            )
        }
    }
}
