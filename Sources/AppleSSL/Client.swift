import Async
import Security
import Foundation
import Dispatch

/// An SSL client. Can be initialized by upgrading an existing socket or by starting an SSL socket.
extension SSLStream {
    /// Upgrades the connection to SSL.
    public func initializeClient(options: [SSLOption] = []) throws -> Future<Void> {
        let context = try self.initialize(side: .clientSide)
        
        for option in options {
            try option.apply(context)
        }
        
        return try handshake(for: context)
    }
}
