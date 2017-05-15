import HTTP
import Transport
import Sockets
import TLS
import Dispatch

/// TCP and TLS client from Engine package.
public final class EngineClient: ClientProtocol {
    public static let factory = EngineClientFactory()
    
    /// The connected HTTP client
    public let client: HTTP.Client
    
    /// Settings
    let hostname: String
    let port: Port
    let securityLayer: SecurityLayer
    let proxy: Proxy?
    
    /// Creates a new Engine client
    public init(
        hostname: String,
        port: Port,
        securityLayer: SecurityLayer,
        proxy: Proxy?
    ) throws {
        self.hostname = hostname
        self.port = port
        self.securityLayer = securityLayer
        self.proxy = proxy
        
        if let proxy = proxy {
            client = try makeClient(
                hostname: proxy.hostname,
                port: proxy.port,
                securityLayer: proxy.securityLayer
            )
        } else {
            client = try makeClient(
                hostname: hostname,
                port: port,
                securityLayer: securityLayer
            )
        }
    }
    
    public func respond(to request: Request) throws -> Response {
        if proxy != nil {
            request.uri.path = "\(securityLayer.scheme)://\(hostname):\(port)" + request.uri.path
        }
        return try client.respond(to: request)
    }
}

public typealias EngineClientFactory = ClientFactory<EngineClient>

// MARK: Private

private func makeClient(
    hostname: String,
    port: Port,
    securityLayer: SecurityLayer
) throws -> HTTP.Client {
    let client: HTTP.Client
    
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
