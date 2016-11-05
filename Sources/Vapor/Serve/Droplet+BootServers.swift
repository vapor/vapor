import Core
import HTTP
import Transport

public typealias ServerConfig = (host: String, port: Int, securityLayer: SecurityLayer)

// MARK: Booting

extension Droplet {
    public func bootServers(_ s: [String: ServerConfig]? = nil) throws {
        let configs: [String: ServerConfig]
        if let s = s {
            configs = s
        } else {
            configs = parseServersConfig()
        }

        for (name, config) in configs {
            bootedServers += try bootServer(config, name: name)
        }
    }

    public func bootServer(_ config: ServerConfig, name: String) throws -> ServerProtocol {
        var message: [String] = []
        message += "Server '\(name)' starting"
        message += "at \(config.host):\(config.port)"
        if config.securityLayer.isSecure {
            message += "🔒"
        }
        let info = message.joined(separator: " ")

        console.output(info, style: .info)
        return try self.server.start(
            host: config.host,
            port: config.port,
            securityLayer: config.securityLayer,
            responder: self,
            errors: serverErrors
        )
    }

}

// MARK: Parsing

extension Droplet {

    func parseServersConfig() -> [String: ServerConfig] {
        if let s = config["servers"]?.object {
            var servers: [String: ServerConfig] = [:]
            for (name, server) in s {
                guard let _ = server.object else {
                    log.warning("Invalid server configuration for '\(name)'.")
                    continue
                }

                let security = config["servers", name, "securityLayer"]?.string ?? "none"
                let securityLayer: SecurityLayer
                do {
                    securityLayer = try parseSecurityLayer(security, name: name)
                } catch {
                    log.warning("Invalid security layer for '\(name)'.")
                    continue
                }

                let host = config["servers", name, "host"]?.string ?? "0.0.0.0"
                let port = config["servers", name, "port"]?.int ?? 8080

                servers[name] = (host, port, securityLayer)
            }

            return servers
        } else {
            log.debug("No 'servers.json' configuration found, using defaults.")
            return [
                "default": ("0.0.0.0", 8080, .none)
            ]
        }
    }

    func parseSecurityLayer(_ security: String, name: String) throws -> SecurityLayer {
        let securityLayer: SecurityLayer

        switch security {
        case "tls":
            if let tlsConfig = config["servers", name, "tls"]?.object {
                let config = try parseTLSConfig(tlsConfig, mode: .server)
                securityLayer = .tls(config)
            } else {
                log.warning("No TLS configuration supplied, using default.")
                securityLayer = .tls(nil)
            }
        case "none":
            securityLayer = .none
        default:
            securityLayer = .none
            log.error("Invalid security layer: \(security), defaulting to none.")
        }

        return securityLayer
    }
}

