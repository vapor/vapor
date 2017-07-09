import HTTP
import TLS
import Transport

/// Represents an HTTP server.
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
    
    /// Unique name for this type of server
    static var name: String { get }
}

extension ServerProtocol {
    public static var name: String {
        return "\(self)".replacingOccurrences(of: "Server", with: "").lowercased()
    }
}
