import Transport

public struct ServerConfig {
    public var hostname: String
    public var port: Port
    public var securityLayer: SecurityLayer
    
    public init(
        hostname: String = "0.0.0.0",
        port: Port = 8080,
        securityLayer: SecurityLayer = .none
    ) {
        self.hostname = hostname
        self.port = port
        self.securityLayer = securityLayer
    }
}

extension ServerConfig {
    public static func `default`() -> ServerConfig {
        return ServerConfig(
            hostname: "0.0.0.0",
            port: 8080,
            securityLayer: .none
        )
    }
}
