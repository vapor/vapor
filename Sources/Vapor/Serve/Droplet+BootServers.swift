import Core
import HTTP
import Transport

public enum ServerConfig {
    case http(name: String, host: String, port: Int, securityLayer: SecurityLayer)
}

// MARK: Booting

extension Droplet {
    func bootServers(_ s: [ServerConfig]? = nil) throws {
        let servers: [ServerConfig]
        if let s = s {
            servers = s
        } else {
            servers = parseServersConfig()
        }

        var bootedServers = 0
        for server in servers {
            try bootServer(server, isLastServer: bootedServers == servers.count - 1)
            bootedServers += 1
        }
    }

    func bootServer(_ server: ServerConfig, isLastServer: Bool) throws {
        switch server {
        case .http(name: let name, host: let host, port: let port, securityLayer: let securityLayer):
            let runInBackground = !isLastServer

            var message: [String] = []
            message += "Server '\(name)' starting"
            if runInBackground {
                message += "in background"
            }
            message += "at \(host):\(port)"
            if securityLayer.isSecure {
                message += "🔒"
            }
            let info = message.joined(separator: " ")

            if runInBackground {
                _ = try background { [weak self] in
                    guard let welf = self else {
                        return
                    }
                    do {
                        welf.console.output(info, style: .info)
                        try welf.server.start(host: host, port: port, securityLayer: securityLayer, responder: welf, errors: welf.serverErrors)
                    } catch {
                        welf.console.output("Background server start error: \(error)", style: .error)
                    }
                }
            } else {
                console.output(info, style: .info)
                try self.server.start(host: host, port: port, securityLayer: securityLayer, responder: self, errors: serverErrors)
            }
        }
    }

}

// MARK: Parsing

extension Droplet {

    func parseServersConfig() -> [ServerConfig] {
        if let s = config["servers"]?.object {
            var servers: [ServerConfig] = []
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

                servers.append(.http(name: name, host: host, port: port, securityLayer: securityLayer))
            }
            return servers
        } else {
            log.debug("No 'servers.json' configuration found, using defaults.")
            return [.http(name: "default", host: "0.0.0.0", port: 8080, securityLayer: .none)]
        }
    }

    func parseSecurityLayer(_ security: String, name: String) throws -> SecurityLayer {
        let securityLayer: SecurityLayer

        switch security {
        case "tls":
            if let tlsConfig = config["servers", name, "tls"]?.object {
                let config = try parseTLSConfig(tlsConfig)
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

