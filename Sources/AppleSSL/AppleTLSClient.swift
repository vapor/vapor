import Async
import JunkDrawer
import Security
import TCP
import TLS

/// A TLS client implemented by Apple security module.
public struct AppleTLSClient: TLSClient {
    /// The TLS socket.
    public let socket: AppleTLSSocket

    /// See TLSClient.settings
    public let settings: TLSClientSettings

    /// Underlying TCP client.
    private let tcp: TCPClient

    /// Create a new `AppleTLSClient`
    public init(tcp: TCPClient, using settings: TLSClientSettings) throws {
        let socket = try AppleTLSSocket(tcp: tcp.socket, protocolSide: .clientSide)

        if let clientCertificate = settings.clientCertificate {
            try socket.context.setCertificate(to: clientCertificate)
        }

        if let peerDomainName = settings.peerDomainName {
            let status = SSLSetPeerDomainName(socket.context, peerDomainName, peerDomainName.count)
            guard status == 0 else {
                throw AppleTLSError.secError(status)
            }
        }

        self.tcp = tcp
        self.settings = settings
        self.socket = socket
    }

    /// Connects and handshakes to the remote server
    public func connect(hostname: String, port: UInt16) throws {
        try tcp.connect(hostname: hostname, port: port)
    }

    /// See TLSClient.close
    public func close() {
        socket.close()
        tcp.close()
    }
}

/// MARK: Stream

extension AppleTLSClient {
    /// Create a dispatch socket stream for this client.
    public func stream(on eventLoop: EventLoop) -> DispatchSocketStream<AppleTLSSocket> {
        return socket.stream(on: eventLoop)
    }
}
