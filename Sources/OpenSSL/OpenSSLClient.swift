import Async
import COpenSSL
import TCP
import TLS

/// A TLS client implemented by COpenSSL.
public final class OpenSSLClient: TLSClient {
    /// The TLS socket.
    public let socket: OpenSSLSocket

    /// See TLSClient.settings
    public var settings: TLSClientSettings

    /// Underlying TCP client.
    private let tcp: TCPClient

    /// Create a new `OpenSSLClient`
    public init(tcp: TCPClient, using settings: TLSClientSettings) throws {
        let socket = try OpenSSLSocket(tcp: tcp.socket, method: .tls1_2, side: .client)
        self.settings = settings
        self.socket = socket
        self.tcp = tcp
    }

    /// See TLSClient.connect
    public func connect(hostname: String, port: UInt16) throws {
        var hostname = hostname
        try tcp.connect(hostname: hostname, port: port)
        SSL_ctrl(socket.cSSL, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)
        SSL_connect(socket.cSSL)
    }

    /// See TLSClient.close
    public func close() {
        socket.close()
        tcp.close()
    }
}

/// MARK: Stream

extension OpenSSLClient {
    /// Create a dispatch socket stream for this client.
    public func stream(on eventLoop: EventLoop) -> DispatchSocketStream<OpenSSLSocket> {
        return socket.stream(on: eventLoop)
    }
}
