import Async
import TCP
import COperatingSystem
import COpenSSL
import TLS

/// Upgrades TCP Sockets to a BasicSSLClient reliant on the OpenSSL
public final class OpenSSLClientUpgrader: SSLClientUpgrader {
    /// Creates a new upgrader
    public init() {}
    
    /// Upgrades a client socket
    public func upgrade(socket: TCPSocket, settings: SSLClientSettings, eventLoop: EventLoop) throws -> Future<BasicSSLClient> {
        let client = try OpenSSLClient(upgrading: socket, settings: settings, on: eventLoop)
        
        if var peerDomainName = settings.peerDomainName {
            SSL_ctrl(client.ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, numericCast(TLSEXT_NAMETYPE_host_name), &peerDomainName)
        }
        
        return client.connected.future.map { BasicSSLClient(boxing: client) }
    }
}

// Upgrades TCP Sockets to a BasicSSLPeer reliant on OpenSSL
public final class OpenSSLPeerUpgrader: SSLPeerUpgrader {
    /// Creates a new upgrader
    public init() {}

    /// Upgrades a remote peer socket
    public func upgrade(socket: TCPSocket, settings: SSLServerSettings, eventLoop: EventLoop) throws -> Future<BasicSSLPeer> {
        let peer = try OpenSSLPeer(upgrading: socket, settings: settings, on: eventLoop)

        return peer.connected.future.map { BasicSSLPeer(boxing: peer) }
    }
}
