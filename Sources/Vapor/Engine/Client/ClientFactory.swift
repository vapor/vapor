import HTTP
import Transport
import Sockets
import TLS

/// TCP and TLS clients from engine
/// wrapped to conform to ClientProtocol.
public final class ClientFactory<C: ClientProtocol>: ClientFactoryProtocol {
    public let defaultProxy: Proxy?
    
    /// Create a new ClientFactory
    public init(defaultProxy: Proxy? = nil) {
        self.defaultProxy = defaultProxy
    }
    
    /// Creates a new client with the supplied connection info
    public func makeClient(
        hostname: String,
        port: Port,
        securityLayer: SecurityLayer,
        proxy: Proxy?
    ) throws -> ClientProtocol {
        return try C(
            hostname: hostname,
            port: port,
            securityLayer: securityLayer,
            proxy: proxy
        )
    }
    
    /// Responds to the request
    public func respond(to request: Request) throws -> Response {
        return try makeClient(for: request).respond(to: request)
    }
}

// MARK: Service

extension ClientFactory: Service {
    /// See Service.name
    public static var serviceName: String {
        return C.serviceName
    }

    /// See Service.make
    public static func makeService(for drop: Droplet) throws -> ClientFactory? {
        let proxy: Proxy?
        
        let config = drop.config
        if let proxyConfig = config["client", "proxy"]?.object {
            guard let hostname = proxyConfig["hostname"]?.string else {
                throw ConfigError.missing(
                    key: ["proxy", "hostname"],
                    file: "client",
                    desiredType: String.self
                )
            }
            
            guard let port = proxyConfig["port"]?.int?.port else {
                throw ConfigError.missing(
                    key: ["proxy", "port"],
                    file: "client",
                    desiredType: Port.self
                )
            }
            
            let securityLayer = try config.makeSecurityLayer(
                serverConfig: Config(proxyConfig),
                file: "client"
            )
            
            proxy = Proxy(
                hostname: hostname,
                port: port,
                securityLayer: securityLayer
            )
        } else {
            proxy = nil
        }
        
        return .init(defaultProxy: proxy)
    }
}
