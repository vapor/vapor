import Async
import COpenSSL
import Foundation

/// A remote peer. This class should be used on a TCP server to accept SSL connections/upgrades.
extension SSLStream {
    /// Upgrades the peer to SSL
    public func initializePeer(certificate: String, key: String) throws -> Future<Void> {
        let context = try self.initialize(
            side: .server(certificate: certificate, key: key),
            method: .tls1_2
        )
        
        let ssl = try self.createSSL(for: context)
        
        return try handshake(for: ssl, side: .server(certificate: certificate, key: key))
    }
}
