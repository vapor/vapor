import Transport

public struct ServerConfig {
    public let hostname: String
    public let port: Port
    public let securityLayer: SecurityLayer
    
    public init(
        hostname: String = "0.0.0.0",
        port: Port = 8080,
        _ securityLayer: SecurityLayer = .none
    ) {
        self.hostname = hostname
        self.port = port
        self.securityLayer = securityLayer
    }
}
