import HTTP
import TLS
import Transport

public protocol ServerProtocol {
    init(hostname: String, port: Port, _ securityLayer: SecurityLayer) throws
    func start(_ responder: Responder) throws
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
