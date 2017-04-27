import HTTP
import Transport
import URI
import TLS

/// types conforming to this protocol can be
/// set as the Droplet's `.server`
public protocol ServerFactoryProtocol {
    func makeServer(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws -> ServerProtocol
}

// MARK: TLS

private var _defaultTLSServerContext: () throws -> (TLS.Context) = {
    return try Context(.server)
}

extension ServerProtocol {
    public static var defaultTLSContext: () throws -> (TLS.Context) {
        get {
            return _defaultTLSServerContext
        }
        set {
            _defaultTLSServerContext = newValue
        }
        
    }
}
