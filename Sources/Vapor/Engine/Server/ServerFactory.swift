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

// MARK: Service
extension ServerFactory: Service {
    /// See Service.name
    public static var name: String {
        return S.name
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> ServerFactory<S>? {
        return .init()
    }
}
