import HTTP
import Transport
import URI
import TLS

/// Represents an HTTP client.
public protocol ClientProtocol: Responder {
    init(
        hostname: String,
        port: Port,
        securityLayer: SecurityLayer,
        proxy: Proxy?
    ) throws
    
    /// Unique name for this type of client
    static var serviceName: String { get }
}

extension ClientProtocol {
    public static var serviceName: String {
        return "\(self)".replacingOccurrences(of: "Client", with: "").lowercased()
    }
}

// MARK: Proxy

public struct Proxy {
    var hostname: String
    var port: Port
    var securityLayer: SecurityLayer
}


// MARK: Convenience

extension ClientProtocol {
    public init(
        hostname: String,
        port: Port,
        securityLayer: SecurityLayer
    ) throws {
        try self.init(
            hostname: hostname,
            port: port,
            securityLayer: securityLayer,
            proxy: nil
        )
    }
}

