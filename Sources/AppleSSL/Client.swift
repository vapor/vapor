import Async
import Security
import Foundation
import Dispatch

/// An SSL client. Can be initialized by upgrading an existing socket or by starting an SSL socket.
extension SSLStream {
    /// Upgrades the connection to SSL.
    public func initializeClient(hostname: String, signedBy certificate: String? = nil) throws -> Future<Void> {
        let context = try self.initialize(side: .clientSide)
        
        var hostname = [Int8](hostname.utf8.map { Int8($0) })
        let status = SSLSetPeerDomainName(context, &hostname, hostname.count)
        
        guard status == 0 else {
            throw Error(.sslError(status))
        }
        
        if let certificate = certificate {
            guard let certificate = FileManager.default.contents(atPath: certificate) else {
                throw Error(.certificateNotFound)
            }
            
            try self.setCertificate(to: certificate, for: context)
        }
        
        return try handshake(for: context)
    }
}
