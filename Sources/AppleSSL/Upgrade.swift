import Async
import TCP
import Security
import TLS

///// Upgrades TCP Sockets to a BasicSSLClient reliant on the Apple Secure Transport libraries
//public final class AppleSSLClientUpgrader: TLSClientUpgrader {
//    /// Creates a new upgrader
//    public init() {}
//    
//    /// Upgrades a client socket
//    public func upgrade(socket: TCPSocket, settings: TLSClientSettings, eventLoop: EventLoop) throws -> Future<BasicSSLClient> {
//        let client = try AppleSSLClient(upgrading: socket, settings: settings, on: eventLoop)
//        
//        if let peerDomainName = settings.peerDomainName {
//            try assert(status: SSLSetPeerDomainName(client.context, peerDomainName, peerDomainName.count))
//        }
//        
//        try client.initialize()
//        
//        return client.connected.future.map { BasicSSLClient(boxing: client) }
//    }
//}
//
///// Upgrades TCP Sockets to a BasicSSLPeer reliant on the Apple Secure Transport libraries
//public final class AppleSSLPeerUpgrader: SSLPeerUpgrader {
//    /// Creates a new upgrader
//    public init() {}
//    
//    /// Upgrades a remote peer socket
//    public func upgrade(socket: TCPSocket, settings: SSLServerSettings, eventLoop: EventLoop) throws -> Future<BasicSSLPeer> {
//        let peer = try AppleSSLPeer(upgrading: socket, settings: settings, on: eventLoop)
//        
//        return peer.connected.future.map { BasicSSLPeer(boxing: peer) }
//    }
//}
//
