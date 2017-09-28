import libc
import TCP
import Core

/// Helper that keeps track of a connection counter for an `Address`
fileprivate final class RemoteAddress {
    let address: Address
    var count = 0
    
    init(address: Address) {
        self.address = address
    }
}

/// Validates peers against a set of rules before further processing the peer
///
/// Used to harden a TCP Server against Denial of Service and other attacks.
public final class PeerValidationStream: Core.Stream {
    public typealias Input = TCP.Client
    public typealias Output = TCP.Client
    
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?
    
    /// Limits the amount of connections per IP address to prevent certain Denial of Service attacks
    public var maxConnectionsPerIP: Int
    
    /// The external connection counter
    fileprivate var remotes = [RemoteAddress]()
    
    /// Creates a new
    public init(maxConnectionsPerIP: Int) {
        self.maxConnectionsPerIP = maxConnectionsPerIP
    }
    
    /// Validates incoming clients
    public func inputStream(_ input: Client) {
        // Accept must always set the address
        guard let currentRemoteAddress = input.socket.address else {
            return
        }
        
        var currentRemote: RemoteAddress? = nil
        
        // Looks for currently open connections from this address
        for remote in self.remotes where remote.address == currentRemoteAddress {
            // If there is one, ensure there aren't too many
            guard remote.count < self.maxConnectionsPerIP else {
                self.errorStream?(Error(identifier: "remote-count", reason: "To prevent a possible Denial of Service attack, the user's connection was not served"))
                input.close()
                return
            }
            
            currentRemote = remote
        }
        
        // If the remote address doesn't have connections open
        if currentRemote == nil {
            currentRemote = RemoteAddress(address: currentRemoteAddress)
        }
        
        // Cleans up be decreasing the counter
        input.socket.beforeClose = {
            input.queue.async {
                guard let currentRemote = currentRemote else {
                    return
                }
                
                currentRemote.count -= 1
                
                // Return if there are still connections open
                guard currentRemote.count <= 0 else {
                    return
                }
                
                // Otherwise, remove the remote address
                if let index = self.remotes.index(where: { $0.address == currentRemoteAddress }) {
                    self.remotes.remove(at: index)
                }
            }
        }
        
        outputStream?(input)
    }
}
