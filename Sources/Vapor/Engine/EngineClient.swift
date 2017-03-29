import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS clients from engine
/// wrapped to conform to ClientProtocol.
public final class EngineClient: ClientProtocol {
    let client: Client

    /// Create a new EngineClient
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
            client = try TCPClient(socket)
        case .tls(let context):
            let socket = try TCPInternetSocket(
                scheme: "https",
                hostname: hostname,
                port: port
            )
            let tlsSocket = TLS.InternetSocket(socket, context)
            client = try TLSClient(tlsSocket)
        }
    }

    /// Responds to the request
    public func respond(to request: Request) throws -> Response {
        return try client.respond(to: request)
    }
}
