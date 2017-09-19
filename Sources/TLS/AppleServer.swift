#if os(macOS) || os(iOS)
    import Security
    import Foundation
    
    /// A remote peer. This class should be used on a TCP server to accept SSL connections/upgrades.
    public final class AppleSSLPeer: AppleSSLSocket {
        /// Upgrades the peer to SSL
        public func initialize(certificate: Certificate) throws {
            let context = try self.initialize(side: .serverSide)
            
            try self.setCertificate(to: certificate, for: context)
            
            try handshake(for: context)
        }
    }
#endif
