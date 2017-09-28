#if os(macOS) || os(iOS)
    import Security
    import Core
    import Foundation
    import Dispatch

    /// An SSL client. Can be initialized by upgrading an existing socket or by starting an SSL socket.
    extension AppleSSLSocket {
        /// Upgrades the connection to SSL.
        public func initializeClient(hostname: String, signedBy certificate: Certificate? = nil) throws {
            let context = try self.initialize(side: .clientSide)
            
            var hostname = [Int8](hostname.utf8.map { Int8($0) })
            let status = SSLSetPeerDomainName(context, &hostname, hostname.count)
            
            guard status == 0 else {
                throw Error.sslError(status)
            }
            
            if let certificate = certificate {
                try self.setCertificate(to: certificate, for: context)
            }
            
            try handshake(for: context)
        }
    }
#endif
