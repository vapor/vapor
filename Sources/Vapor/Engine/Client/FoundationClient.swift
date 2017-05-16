import HTTP
import Transport

/// HTTP/HTTPS client from Foundation.
public final class FoundationClient: ClientProtocol {
    /// The connected HTTP client
    let client: HTTP.FoundationClient
    
    /// Settings
    let hostname: String
    let port: Port
    let securityLayer: SecurityLayer
    let proxy: Proxy?
    
    /// Creates a new Foundation client
    public init(
        hostname: String,
        port: Port,
        securityLayer: SecurityLayer,
        proxy: Proxy?
    ) throws{
        self.hostname = hostname
        self.port = port
        self.securityLayer = securityLayer
        self.proxy = proxy
        
        if let proxy = proxy {
            client = HTTP.FoundationClient(
                scheme: proxy.securityLayer.scheme,
                hostname: proxy.hostname,
                port: proxy.port
            )
        } else {
            client = HTTP.FoundationClient(
                scheme: securityLayer.scheme,
                hostname: hostname,
                port: port
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

public typealias FoundationClientFactory = ClientFactory<FoundationClient>


extension SecurityLayer {
    public var scheme: String {
        let scheme: String
        switch self {
        case .none:
            scheme = "http"
        case .tls:
            scheme = "https"
        }
        return scheme
    }
}
