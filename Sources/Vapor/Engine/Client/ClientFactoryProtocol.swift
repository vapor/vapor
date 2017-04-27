import HTTP
import Transport
import URI
import TLS

/// types conforming to this protocol can be
/// set as the Droplet's `.client`
public protocol ClientFactoryProtocol: Responder {
    func makeClient(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws -> ClientProtocol
}


// MARK: Convenience

extension ClientFactoryProtocol {
    /// Creates a client connected to the server specified
    /// by the supplied request.
    func makeClient(for req: Request, using s: SecurityLayer? = nil) throws -> ClientProtocol {
        // use security layer from input or
        // determine based on req uri scheme
        let securityLayer: SecurityLayer
        if let s = s {
            securityLayer = s
        } else if req.uri.scheme.isSecure {
            securityLayer = try .tls(_defaultTLSClientContext())
        } else {
            securityLayer = .none
        }
        
        return try makeClient(
            hostname: req.uri.hostname,
            port: req.uri.port ?? req.uri.scheme.port,
            securityLayer
        )
    }
}

// MARK: TLS

private var _defaultTLSClientContext: () throws -> (TLS.Context) = {
    return try Context(.client)
}

extension ClientProtocol {
    public static var defaultTLSContext: () throws -> (TLS.Context) {
        get {
            return _defaultTLSClientContext
        }
        set {
            _defaultTLSClientContext = newValue
        }
        
    }
}
