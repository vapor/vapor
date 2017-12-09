import Async
import TCP
import Security
import TLS

public final class AppleSSLClientUpgrader: SSLClientUpgrader {
    public init() {}
    
    public func upgrade(socket: TCPSocket, settings: SSLClientSettings, eventLoop: EventLoop) throws -> Future<BasicSSLClient> {
        let client = try AppleSSLClient(upgrading: socket, settings: settings, on: eventLoop)
        
        if let peerDomainName = settings.peerDomainName {
            try assert(status: SSLSetPeerDomainName(client.context, peerDomainName, peerDomainName.count))
        }
        
        try client.initialize()
        
        return client.connected.future.map { BasicSSLClient(boxing: client) }
    }
}

public final class AppleSSLPeerUpgrader: SSLPeerUpgrader {
    public init() {}
    
    public func upgrade(socket: TCPSocket, settings: SSLServerSettings, eventLoop: EventLoop) throws -> Future<BasicSSLPeer> {
        let peer = try AppleSSLPeer(upgrading: socket, settings: settings, on: eventLoop)
        
        return peer.connected.future.map { BasicSSLPeer(boxing: peer) }
    }
}

