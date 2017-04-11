import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS clients from engine
/// wrapped to conform to ClientProtocol.
public final class EngineClientFactory: ClientFactory {
    public static let shared = EngineClientFactory()
    
    /// Create a new EngineClient
    public func makeClient(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws -> Responder {
        let client: Responder
        
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
        
        return client
    }

    /// Responds to the request
    public func respond(to request: Request) throws -> Response {
        return try makeClient(for: request).respond(to: request)
    }
}
