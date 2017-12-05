import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS servers from engine
/// wrapped to conform to the Server Protocol
public final class EngineServer: ServerProtocol {
    public let server: Server

    /// Create a new EngineServer
    public init(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws {
        switch securityLayer {
        case .none:
            let socket = try TCPInternetSocket(
                scheme: "http",
                hostname: hostname,
                port: port
            )
            server = try TCPServer(socket)
        case .tls(let context):
            let socket = try TCPInternetSocket(
                scheme: "https",
                hostname: hostname,
                port: port
            )
            let tlsSocket = TLS.InternetSocket(socket, context)
            server = try TLSServer(tlsSocket)
        }
    }

    /// Starts the server. 
    /// The supplied Responder will be called
    /// when the server accepts a connection
    public func start(
        _ responder: Responder,
        errors: @escaping ServerErrorHandler
    ) throws {
        try server.start(responder, errors: errors)
    }
}
