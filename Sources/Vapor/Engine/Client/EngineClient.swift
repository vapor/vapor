import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS client from Engine package.
public final class EngineClient: ClientProtocol {
    public static let factory = EngineClientFactory()
    
    public let client: HTTP.Client
    
    /// Creates a new Engine client
    public init(hostname: String, port: Port, _ securityLayer: SecurityLayer) throws {
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
    
    public func respond(to request: Request) throws -> Response {
        return try client.respond(to: request)
    }
}

public typealias EngineClientFactory = ClientFactory<EngineClient>
