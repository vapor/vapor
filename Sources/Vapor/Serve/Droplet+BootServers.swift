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

// MARK: Starting (async booting)

extension Droplet {
    public func start(_ server: ServerProtocol) throws -> Never {
        try server.start(responder: self, errors: serverErrors)
    }
}

// MARK: Booting

extension Droplet {
    func serve(_ config: ServerConfig?) throws -> Never {
        let config = try config ?? makeServerConfig()
        let server = try self.server.make(host: config.host, port: config.port, securityLayer: config.securityLayer)
        try start(server)
    }

    private func makeServerConfig() throws -> ServerConfig {
        let serverConfig = config["server"]
        let port = serverConfig?["port"]?.int ?? cliPort(arguments: arguments) ?? 8080
        let host = serverConfig?["host"]?.string ?? "0.0.0.0"
        let securityLayer = try makeSecurityLayer(serverConfig: serverConfig)
        return ServerConfig(host: host, port: port, securityLayer: securityLayer)
    }

    private func makeSecurityLayer(serverConfig: Settings.Config?) throws -> SecurityLayer {
        let security = serverConfig?["securityLayer"]?.string ?? "none"
        let securityLayer: SecurityLayer

        switch security {
        case "tls":
            if let tlsConfig = serverConfig?["tls"]?.object {
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

//
//    func bootServer(_ server: ServerConfig, name: String, isLastServer: Bool) throws {
//        let runInBackground = !isLastServer
//
//        var message: [String] = []
//        message += "Server '\(name)' starting"
//        if runInBackground {
//            message += "in background"
//        }
//        message += "at \(server.host):\(server.port)"
//        if server.securityLayer.isSecure {
//            message += "🔒"
//        }
//        let info = message.joined(separator: " ")
//
//        if runInBackground {
//            background { [weak self] in
//                guard let welf = self else {
//                    return
//                }
//                do {
//                    welf.console.output(info, style: .info)
//                    try welf.server.start(
//                        host: server.host,
//                        port: server.port,
//                        securityLayer: server.securityLayer,
//                        responder: welf, errors:
//                        welf.serverErrors
//                    )
//                } catch {
//                    welf.console.output("Background server start error: \(error)", style: .error)
//                }
//            }
//        } else {
//            console.output(info, style: .info)
//            try self.server.start(
//                host: server.host,
//                port: server.port,
//                securityLayer: server.securityLayer,
//                responder: self,
//                errors: serverErrors
//            )
//        }
//    }
}

// MARK: Parsing
////
////public final class ServerConfig {
////    let host: String
////    let port: Int
////
////    let securityLayer: SecurityLayer
////
////    init?(config: Settings.Config) {
////
////        let security = config["securityLayer"]?.string ?? "none"
////        let securityLayer: SecurityLayer
////
////        switch security {
////        case "tls":
////            if let tlsConfig = config["tls"]?.object {
////                let config = try parseTLSConfig(tlsConfig, mode: .server)
////                securityLayer = .tls(config)
////            } else {
////                log.warning("No TLS configuration supplied, using default.")
////                securityLayer = .tls(nil)
////            }
////        case "none":
////            securityLayer = .none
////        default:
////            securityLayer = .none
////            log.error("Invalid security layer: \(security), defaulting to none.")
////        }
////
////        return securityLayer
////    }
////}
//
//extension SecurityLayer {
//    init(config: Settings.Config) {
//        let security = config["server", "securityLayer"]?.string ?? "none"
//        switch security {
//            case "tls":
//                if let tlsConfig = config["tls"]?.object {
//
//            }
//            
//        }
//    }
//}

extension Droplet {

//    func parseServersConfig() -> [String: ServerConfig] {
//        if let s = config["servers"]?.object {
//            var servers: [String: ServerConfig] = [:]
//            for (name, server) in s {
//                guard let _ = server.object else {
//                    log.warning("Invalid server configuration for '\(name)'.")
//                    continue
//                }
//
//                let security = config["servers", name, "securityLayer"]?.string ?? "none"
//                let securityLayer: SecurityLayer
//                do {
//                    securityLayer = try parseSecurityLayer(security, name: name)
//                } catch {
//                    log.warning("Invalid security layer for '\(name)'.")
//                    continue
//                }
//
//                let host = config["servers", name, "host"]?.string ?? "0.0.0.0"
//                let port = config["servers", name, "port"]?.int ?? cliPort(arguments: arguments) ?? 8080
//
//                servers[name] = (host, port, securityLayer)
//            }
//
//            return servers
//        } else {
//            log.debug("No 'servers.json' configuration found, using defaults.")
//            let port = cliPort(arguments: arguments) ?? 8080
//            return [
//                "default": ("0.0.0.0", port, .none)
//            ]
//        }
//    }
//
//    func parseSecurityLayer(_ security: String, name: String) throws -> SecurityLayer {
//        let securityLayer: SecurityLayer
//
//        switch security {
//        case "tls":
//            if let tlsConfig = config["servers", name, "tls"]?.object {
//                let config = try parseTLSConfig(tlsConfig, mode: .server)
//                securityLayer = .tls(config)
//            } else {
//                log.warning("No TLS configuration supplied, using default.")
//                securityLayer = .tls(nil)
//            }
//        case "none":
//            securityLayer = .none
//        default:
//            securityLayer = .none
//            log.error("Invalid security layer: \(security), defaulting to none.")
//        }
//
//        return securityLayer
//    }
}


/**
    To support old form quick port setting through config.
*/
func cliPort(arguments: [String]) -> Int? {
    return arguments.value(for: "port")?.int
}
