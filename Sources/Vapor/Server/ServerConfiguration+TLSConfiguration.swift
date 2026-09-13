public import NIOCertificateReloading
public import X509

extension ServerConfiguration {
    /// Transport-level TLS configuration for the server.
    public struct TLSConfiguration: Sendable {
        enum Source {
            case inMemory(certificateChain: [Certificate], privateKey: Certificate.PrivateKey)
            case pemFile(certificateChainPath: String, privateKeyPath: String)
            case reloading(any CertificateReloader)
        }

        let source: Source

        /// Mutual TLS: how the server verifies the certificate a client presents.
        ///
        /// `nil`, the default, means clients are never asked for a certificate. Set it to ask for
        /// one; a chain that verifies reaches handlers as ``Request/peerCertificateChain``.
        ///
        /// ```swift
        /// var tls = ServerConfiguration.TLSConfiguration.pemFile(
        ///     certificateChainPath: "server.pem", privateKeyPath: "server.key")
        /// tls.clientCertificateVerification = .init(trust: .pemFile(path: "client-ca.pem"))
        /// app.serverConfiguration.tlsConfiguration = tls
        /// ```
        ///
        /// Independent of where the server's own credentials come from: any of the sources below,
        /// including a `CertificateReloader`, can be paired with client verification.
        public var clientCertificateVerification: ClientCertificateVerification?

        /// TLS credentials loaded from in-memory X.509 certificates and a private key.
        public static func inMemory(certificateChain: [Certificate], privateKey: Certificate.PrivateKey) -> Self {
            Self.init(source: .inMemory(certificateChain: certificateChain, privateKey: privateKey))
        }

        /// TLS credentials loaded from PEM files on disk.
        public static func pemFile(certificateChainPath: String, privateKeyPath: String) -> Self {
            Self.init(source: .pemFile(certificateChainPath: certificateChainPath, privateKeyPath: privateKeyPath))
        }

        /// TLS credentials supplied by a `CertificateReloader`.
        ///
        /// The caller is responsible for running the reloader. Vapor wires it into the HTTP server
        /// but does not start its task. The reloader must already hold valid credentials when the
        /// server starts or startup fails; for `TimedCertificateReloader`, create it with
        /// `makeReloaderValidatingSources(...)` and call `run()` or use `app.addService(reloader)`
        ///
        /// - Parameter reloader: The reloader that supplies and refreshes the credentials.
        public static func reloading(_ reloader: any CertificateReloader) -> Self {
            Self.init(source: .reloading(reloader))
        }
    }
}

extension ServerConfiguration.TLSConfiguration {
    /// Mutual TLS: what the server trusts when a client presents a certificate, and whether a
    /// client may connect without one.
    public struct ClientCertificateVerification: Sendable {
        /// Where trust comes from: a set of roots, or a verifier of your own.
        public var trust: TrustSource

        /// Whether a client must present a certificate. Defaults to ``Mode/required``.
        public var mode: Mode

        /// - Parameters:
        ///   - trust: Where trust comes from.
        ///   - mode: Whether a client must present a certificate. Defaults to ``Mode/required``.
        public init(trust: TrustSource, mode: Mode = .required) {
            self.trust = trust
            self.mode = mode
        }

        /// Whether a client may connect without a certificate.
        public struct Mode: Sendable, Hashable {
            enum Backing: Hashable {
                case required
                case optional
            }

            let backing: Backing

            /// The client must present a certificate, and it must verify against
            /// ``ClientCertificateVerification/trust``. The chain is verified but no hostname is:
            /// a client has none to check against.
            public static var required: Self { Self(backing: .required) }

            /// The client may connect without a certificate. One it does present must still verify,
            /// and the handshake fails if it does not.
            ///
            /// A handler tells the two apart by whether ``Request/peerCertificateChain`` is `nil`,
            /// so anything that must only serve identified clients has to check it.
            public static var optional: Self { Self(backing: .optional) }
        }

        /// Where the server's trust in client certificates comes from.
        public struct TrustSource: Sendable {
            enum Backing {
                case systemDefaults
                case certificates([Certificate])
                case pemFile(path: String)
                case pemBytes([UInt8])
                case derFile(path: String)
                case derBytes([UInt8])
                case custom(@Sendable ([Certificate]) async throws -> Verdict)
            }

            let backing: Backing

            /// The platform's default trust store.
            public static var systemDefaults: Self { Self(backing: .systemDefaults) }

            /// Trust anchors held in memory.
            public static func certificates(_ trustRoots: [Certificate]) -> Self {
                Self(backing: .certificates(trustRoots))
            }

            /// Trust anchors read from a PEM file, which may hold several.
            public static func pemFile(path: String) -> Self {
                Self(backing: .pemFile(path: path))
            }

            /// Trust anchors given as PEM, which may hold several.
            public static func pemBytes(_ trustRoots: [UInt8]) -> Self {
                Self(backing: .pemBytes(trustRoots))
            }

            /// A single trust anchor read from a DER file.
            public static func derFile(path: String) -> Self {
                Self(backing: .derFile(path: path))
            }

            /// A single trust anchor given as DER.
            public static func derBytes(_ trustRoot: [UInt8]) -> Self {
                Self(backing: .derBytes(trustRoot))
            }

            /// A verifier of your own, in place of any trust roots.
            ///
            /// `verify` is handed the chain exactly as the client presented it, leaf first, and
            /// decides. Nothing is checked before it runs — not expiry, not the signature chain —
            /// so it carries the whole burden of trust. Throwing rejects the client, as does
            /// returning ``Verdict/rejected(reason:)``.
            public static func custom(
                _ verify: @escaping @Sendable ([Certificate]) async throws -> Verdict
            ) -> Self {
                Self(backing: .custom(verify))
            }
        }

        /// A custom verifier's decision about the chain a client presented.
        public enum Verdict: Sendable {
            /// The client is trusted. The chain given here becomes ``Request/peerCertificateChain``;
            /// with `nil` the handler sees no chain even though the client was verified.
            case verified(ValidatedCertificateChain? = nil)

            /// The client is not trusted, and the handshake fails. `reason` goes to the server's log.
            case rejected(reason: String)
        }
    }
}
