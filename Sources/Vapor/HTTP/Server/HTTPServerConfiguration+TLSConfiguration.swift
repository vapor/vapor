import X509

extension ServerConfiguration {
    /// Transport-level TLS configuration for the server.
    public struct TLSConfiguration: Sendable {
        enum Source {
            case inMemory(certificateChain: [Certificate], privateKey: Certificate.PrivateKey)
            case pemFile(certificateChainPath: String, privateKeyPath: String)
        }

        var source: Source

        /// TLS credentials loaded from in-memory X.509 certificates and a private key.
        public static func inMemory(certificateChain: [Certificate], privateKey: Certificate.PrivateKey) -> Self {
            Self.init(source: .inMemory(certificateChain: certificateChain, privateKey: privateKey))
        }

        /// TLS credentials loaded from PEM files on disk.
        public static func pemFile(certificateChainPath: String, privateKeyPath: String) -> Self {
            Self.init(source: .pemFile(certificateChainPath: certificateChainPath, privateKeyPath: privateKeyPath))
        }
    }
}
