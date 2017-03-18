import Core
import HTTP
import Transport
import TLS

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

// MARK: Booting

extension Droplet {
    public func serve(_ config: ServerConfig? = nil) throws -> Never {
        let config = try config ?? makeServerConfig()
        let server = try self.server.init(
            hostname: config.hostname,
            port: config.port,
            config.securityLayer
        )

        log.info("Starting server on \(config.hostname):\(config.port)")
        try server.start(self, errors: serverErrors)

        // don't enforce -> Never on protocol because of Swift warnings
        log.error("server did not block execution")
        exit(1)
    }
}

func cliPort(arguments: [String]) -> Port? {
    return arguments.value(for: "port")?.int?.port
}
