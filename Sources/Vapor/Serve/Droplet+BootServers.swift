import Core
import HTTP
import Transport

public typealias ServerConfig = (host: String, port: Int, securityLayer: SecurityLayer)

// MARK: Starting (async booting)

extension Droplet {
    public func startServers(_ s: [String: ServerConfig]? = nil) throws {
        let configs: [String: ServerConfig]
        if let s = s {
            configs = s
        } else {
            configs = parseServersConfig()
        }
        
        for (name, config) in configs {
            try startServer(config, name: name)
        }
    }
    
    public func startServer(_ config: ServerConfig, name: String) throws -> ServerProtocol {
        var message: [String] = []
        message += "Server '\(name)' starting"
        message += "at \(config.host):\(config.port)"
        if config.securityLayer.isSecure {
            message += "🔒"
        }
        let info = message.joined(separator: " ")
        
        console.output(info, style: .info)
        let server = try self.server.startAsync(
            host: config.host,
            port: config.port,
            securityLayer: config.securityLayer,
            responder: self,
            errors: serverErrors
        )
        startedServers[name] = server
        return server
    }

    public func stopServers() {
        // release all servers, which closes the listening socket(s)
        startedServers.removeAll()
    }
    
    public func stopServer(name: String) {
        guard let server = startedServers[name] else { return }
        startedServers.removeValue(forKey: name)
        var message: [String] = []
        message += "Stopping server '\(name)'"
        message += "at \(server.host):\(server.port)"
        if server.securityLayer.isSecure {
            message += "🔒"
        }
        let info = message.joined(separator: " ")
        
        console.output(info, style: .info)
    }
}

// MARK: Booting

extension Droplet {
    func bootServers(_ s: [String: ServerConfig]? = nil) throws {
        let servers: [String: ServerConfig]
        if let s = s {
            servers = s
        } else {
            servers = parseServersConfig()
        }

        var bootedServers = 0
        for (name, server) in servers {
            try bootServer(server, name: name, isLastServer: bootedServers == servers.count - 1)
            bootedServers += 1
        }
    }

    func bootServer(_ server: ServerConfig, name: String, isLastServer: Bool) throws {
        let runInBackground = !isLastServer

        var message: [String] = []
        message += "Server '\(name)' starting"
        if runInBackground {
            message += "in background"
        }
        message += "at \(server.host):\(server.port)"
        if server.securityLayer.isSecure {
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
                    try welf.server.start(
                        host: server.host,
                        port: server.port,
                        securityLayer: server.securityLayer,
                        responder: welf, errors:
                        welf.serverErrors
                    )
                } catch {
                    welf.console.output("Background server start error: \(error)", style: .error)
                }
            }
        } else {
            console.output(info, style: .info)
            try self.server.start(
                host: server.host,
                port: server.port,
                securityLayer: server.securityLayer,
                responder: self,
                errors: serverErrors
            )
        }
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

