import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS servers from engine
/// wrapped to conform to ServerProtocol.
public final class ServerFactory<S: ServerProtocol>: ServerFactoryProtocol {
    /// Create a new ServerFactory
    public init() {}
    
    /// Creates a new server with the supplied connection info
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
