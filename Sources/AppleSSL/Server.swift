import Async
import Security
import Foundation

/// A remote peer. This class should be used on a TCP server to accept SSL connections/upgrades.
extension SSLStream {
    /// Upgrades the peer to SSL
    public func initializePeer(signedBy certificate: String) throws -> Future<Void> {
        let context = try self.initialize(side: .serverSide)
        
        try SSLOption.useCertificate(atPath: certificate).apply(context)
        
        return try handshake(for: context)
    }
}
