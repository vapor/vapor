public import NIOCertificateReloading
public import X509

extension ServerConfiguration {
    /// Transport-level TLS configuration for the server.
    public struct TLSConfiguration: Sendable {
        enum Source {
            case inMemory(certificateChain: [Certificate], privateKey: Certificate.PrivateKey)
            case pemFile(certificateChainPath: String, privateKeyPath: String, refreshInterval: Duration?)
            case reloading(any CertificateReloader)
        }

        let source: Source

        /// TLS credentials loaded from in-memory X.509 certificates and a private key.
        public static func inMemory(certificateChain: [Certificate], privateKey: Certificate.PrivateKey) -> Self {
            Self.init(source: .inMemory(certificateChain: certificateChain, privateKey: privateKey))
        }

        /// TLS credentials loaded from PEM files on disk.
        ///
        /// - Parameters:
        ///   - certificateChainPath: Path to the PEM-encoded certificate chain.
        ///   - privateKeyPath: Path to the PEM-encoded private key.
        ///   - refreshInterval: When set to a positive duration, Vapor creates and runs a
        ///     `TimedCertificateReloader` on that interval. When `nil`, the files are loaded once.
        public static func pemFile(certificateChainPath: String, privateKeyPath: String, refreshInterval: Duration? = nil) -> Self {
            Self.init(source: .pemFile(certificateChainPath: certificateChainPath, privateKeyPath: privateKeyPath, refreshInterval: refreshInterval))
        }

        /// TLS credentials supplied by a `CertificateReloader`.
        ///
        /// The caller is responsible for running the reloader. Vapor wires it into the HTTP server
        /// but does not start its task. The reloader must already hold valid credentials when the
        /// server starts or startup fails; for `TimedCertificateReloader`, create it with
        /// `makeReloaderValidatingSources(...)` and call `run()`.
        ///
        /// - Parameter reloader: The reloader that supplies and refreshes the credentials.
        public static func reloading(_ reloader: any CertificateReloader) -> Self {
            Self.init(source: .reloading(reloader))
        }
    }
}
