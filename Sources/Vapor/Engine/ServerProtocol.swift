import HTTP
import TLS
import Transport

/// types conforming to this protocol can
/// be set as the Droplet's `.server`
public protocol ServerProtocol {
    /// creates a new server
    init(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws

    /// starts the server, using the responder
    /// to respond to accepted requests
    func start(
        _ responder: Responder,
        errors: @escaping ServerErrorHandler
    ) throws
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
