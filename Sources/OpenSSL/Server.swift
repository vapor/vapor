import Async
import COpenSSL
import Foundation

/// A remote peer. This class should be used on a TCP server to accept SSL connections/upgrades.
extension SSLStream {
    /// Upgrades the peer to SSL
    public func initializePeer(certificate: String, key: String) throws -> Future<Void> {
        let ssl = try self.initialize(side:
            .server(certificate: certificate, key: key)
        )
        
        return try handshake(for: ssl, side: .server(certificate: certificate, key: key))
    }
}
