import Core
import HTTP
import Transport
import TLS

public struct ServerConfig {
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer
    public init(host: String = "0.0.0.0", port: Int = 8080, securityLayer: SecurityLayer = .none) {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
    }
}

// MARK: Booting

extension Droplet {
    public func serve(_ config: ServerConfig? = nil) throws -> Never {
        let config = try config ?? makeServerConfig()
        let server = try self.server.make(host: config.host, port: config.port, securityLayer: config.securityLayer)
        try server.start(responder: self, errors: serverErrors)
    }
}

func cliPort(arguments: [String]) -> Int? {
    return arguments.value(for: "port")?.int
}
