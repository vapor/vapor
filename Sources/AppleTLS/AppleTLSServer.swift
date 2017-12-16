import Security
import TCP
import TLS

/// A TLS server implemented by Apple security module.
public struct AppleTLSServer: TLSServer {
    /// The TLS socket.
    public let socket: AppleTLSSocket

    /// See TLSServer.settings
    public let settings: TLSServerSettings

    /// Underlying TCP server.
    private let tcp: TCPServer

    /// Create a new `AppleTLSServer`
    public init(tcp: TCPServer, using settings: TLSServerSettings) throws {
        let socket = try AppleTLSSocket(tcp: tcp.socket, protocolSide: .serverSide)
        try socket.context.setCertificate(to: settings.publicKey)
        self.tcp = tcp
        self.settings = settings
        self.socket = socket
    }

    /// Starts the TLS server
    public func start() throws {
        try tcp.start(hostname: settings.hostname, port: 443, backlog: 4096)
    }

    /// See TLSClient.close
    public func close() {
        socket.close()
        tcp.stop()
    }
}
