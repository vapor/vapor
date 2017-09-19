#if os(macOS) || os(iOS)
    import Security
    import Foundation
    
    public final class AppleSSLServer: AppleSSLSocket {
        public func initialize(certificate: Data) throws {
            let context = try self.initialize(side: .serverSide)
            
            try self.setCertificate(to: certificate, for: context)
            
            try handshake(for: context)
        }
    }
#endif
