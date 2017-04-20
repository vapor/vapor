import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS clients from engine
/// wrapped to conform to ClientProtocol.
public final class ServerFactory<S: ServerProtocol>: ServerFactoryProtocol {
    /// Create a new ClientFactory
    public init() {}
    
    /// Creates a new client with the supplied connection info
    public func makeServer(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws -> ServerProtocol {
        return try S(
            hostname: hostname,
            port: port,
            securityLayer
        )
    }
}

extension ServerFactory: ConfigInitializable {
    public convenience init(config: Configs.Config) throws {
        self.init()
    }
}
