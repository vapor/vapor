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
}

// MARK: Proxy

public struct Proxy {
    public var hostname: String
    public var port: Port
    public var securityLayer: SecurityLayer
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

