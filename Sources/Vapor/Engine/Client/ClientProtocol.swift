import HTTP
import Transport
import URI
import TLS

/// Represents an HTTP client.
public protocol ClientProtocol: Responder {
    init(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer,
        proxy: Proxy?
    ) throws
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
        _ securityLayer: SecurityLayer
    ) throws {
        try self.init(
            hostname: hostname,
            port: port,
            securityLayer,
            proxy: nil
        )
    }
}

