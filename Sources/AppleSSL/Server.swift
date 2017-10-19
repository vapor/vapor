import Async
import Security
import Foundation

/// A remote peer. This class should be used on a TCP server to accept SSL connections/upgrades.
extension SSLStream {
    /// Upgrades the peer to SSL
    public func initializePeer(signedBy certificate: String) throws -> Future<Void> {
        let context = try self.initialize(side: .serverSide)
        
        guard let certificate = FileManager.default.contents(atPath: certificate) else {
            throw Error(.certificateNotFound)
        }
        
        try self.setCertificate(to: certificate, for: context)
        
        return try handshake(for: context)
    }
}
