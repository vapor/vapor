import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS clients from engine
/// wrapped to conform to ClientProtocol.
public final class ClientFactory<C: ClientProtocol>: ClientFactoryProtocol {
    /// Create a new ClientFactory
    public init() {}
    
    /// Creates a new client with the supplied connection info
    public func makeClient(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws -> ClientProtocol {
        return try C(
            hostname: hostname,
            port: port,
            securityLayer
        )
    }
    
    /// Responds to the request
    public func respond(to request: Request) throws -> Response {
        return try makeClient(for: request).respond(to: request)
    }
}

extension ClientFactory: ConfigInitializable {
    public convenience init(config: Configs.Config) throws {
        self.init()
    }
}
