import Strand

extension Application {
    func serve() throws {
        if let servers = config["servers"].object {
            var bootedServers = 0
            for (key, server) in servers {
                guard let server = server.object else {
                    console.output("Invalid server configuration for \(key).", style: .error, newLine: true)
                    continue
                }

                try bootServer(config: server, name: key, isLastServer: bootedServers == servers.keys.count - 1)
                bootedServers += 1
            }
        } else {
            console.output("No servers.json configuration found.", style: .warning, newLine: true)

            let host = config["servers", "default", "host"].string
                ?? config["app", "host"].string
                ?? "localhost"
            let port = config["servers", "default", "port"].int
                ?? config["app", "port"].int
                ?? 8080
            let security = config["servers", "default", "securityLayer"].string
                ?? config["app", "securityLayer"].string
                ?? "none"
            let securityLayer: SecurityLayer = security.securityLayer

            var message = "Starting server at \(host):\(port)"
            if securityLayer == .tls {
                message += " 🔒"
            }

            console.output(message, style: .info)
            try server.start(host: host, port: port,
                             securityLayer: securityLayer,
                             responder: self,
                             errors: self.serverErrors)

        }
    }

    func bootServer(config: [String: Polymorphic], name: String, isLastServer: Bool) throws {
        let securityLayer: SecurityLayer = config["securityLayer"].string == "tls" ? .tls : .none

        let host = config["host"].string ?? "localhost"
        let port = config["port"].int ?? 80

        let runInBackground = !isLastServer

        var message: [String] = []
        message += "Server '\(name)' starting"
        if runInBackground {
            message += "in background"
        }
        message += "at \(host):\(port)"
        if securityLayer == .tls {
            message += "🔒"
        }
        let info = message.joined(separator: " ")

        if runInBackground {
            _ = try Strand { [weak self] in
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
