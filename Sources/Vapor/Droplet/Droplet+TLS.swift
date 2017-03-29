import TLS
import Transport

extension Droplet {
    internal func makeServerConfig() throws -> ServerConfig {
        let serverConfig = config["server"]
        let port = serverConfig?["port"]?.int?.port ?? cliPort(arguments: arguments) ?? 8080
        let hostname = serverConfig?["host"]?.string ?? "0.0.0.0"
        let securityLayer = try makeSecurityLayer(serverConfig: serverConfig)
        return ServerConfig(hostname: hostname, port: port, securityLayer)
    }

    private func makeSecurityLayer(serverConfig: Settings.Config?) throws -> SecurityLayer {
        let serverConfig = serverConfig?.converted(to: Node.self)
        let security = serverConfig?["securityLayer"]?.string ?? "none"
        let securityLayer: SecurityLayer

        switch security {
        case "tls":
            if let tlsConfig = serverConfig?["tls"]?.object {
                let config = try parseTLSConfig(tlsConfig, mode: .server)
                securityLayer = .tls(config)
            } else {
                log.warning("No TLS configuration supplied, using default.")
                securityLayer = .tls(try server.defaultTLSContext())
            }
        case "none":
            securityLayer = .none
        default:
            securityLayer = .none
            log.error("Invalid security layer: \(security), defaulting to none.")
        }

        return securityLayer
    }

    func parseTLSConfig(_ tlsConfig: [String: Node], mode: TLS.Mode) throws -> TLS.Context {
        let verifyHost = tlsConfig["verifyHost"]?.bool ?? true
        let verifyCertificates = tlsConfig["verifyCertificates"]?.bool ?? true

        let certs = parseTLSCertificates(tlsConfig)
        let config = try TLS.Context(
            mode,
            certs,
            verifyHost: verifyHost,
            verifyCertificates: verifyCertificates
        )

        return config
    }

    func parseTLSCertificates(_ tlsConfig: [String: Node]) -> TLS.Certificates {
        let certs: TLS.Certificates

        if let certsConfig = tlsConfig["certificates"]?.string {
            switch certsConfig {
            case "none":
                certs = .none
            case "chain":
                if let chain = tlsConfig["chainFile"]?.string {
                    let sig = parseTLSSignature(tlsConfig)
                    certs = .chain(chainFile: chain, signature: sig)
                } else {
                    log.error("No TLS `chainFile` supplied, defaulting to none.")
                    certs = .none
                }
            case "files":
                if
                    let cert = tlsConfig["certificateFile"]?.string,
                    let key = tlsConfig["privateKeyFile"]?.string
                {
                    let sig = parseTLSSignature(tlsConfig)
                    certs = .files(certificateFile: cert, privateKeyFile: key, signature: sig)
                } else {
                    log.error("No TLS `certificateFile` or `privateKeyFile` supplied, defaulting to none.")
                    certs = .none
                }
            case "ca":
                let sig = parseTLSSignature(tlsConfig)
                certs = .certificateAuthority(signature: sig)
            case "mozilla":
                print("[deprecated] Mozilla certificates have been deprecated and will be removed in future releases. Using 'defaults' instead.")
                certs = .defaults
            case "openbsd":
                certs = .openbsd
            case "defaults", "default":
                certs = .defaults
            default:
                log.error("Unsupported TLS certificates \(certsConfig), defaulting to none.")
                certs = .none
            }
        } else {
            log.error("No TLS certificates supplied, defaulting to none.")
            certs = .none
        }

        return certs
    }

    func parseTLSSignature(_ tlsConfig: [String: Node]) -> TLS.Certificates.Signature {
        let signature: TLS.Certificates.Signature

        if let sigConfig = tlsConfig["signature"]?.string {
            switch sigConfig {
            case "selfSigned":
                signature = .selfSigned
            case "signedFile":
                if let caFile = tlsConfig["caCertificateFile"]?.string {
                    signature = .signedFile(caCertificateFile: caFile)
                } else {
                    signature = .selfSigned
                    log.error("No TLS signature caCertificateFile supplied, defaulting to selfSigned.")
                }
            case "signedDirectory":
                if let caDir = tlsConfig["caCertificateDirectory"]?.string {
                    signature = .signedDirectory(caCertificateDirectory: caDir)
                } else {
                    signature = .selfSigned
                    log.error("No TLS signature caCertificateDirectory supplied, defaulting to selfSigned.")
                }
            default:
                log.error("Unsupported TLS signature \(sigConfig), defaulting to selfSigned.")
                signature = .selfSigned
            }
        } else {
            log.error("No TLS signature supplied, defaulting to selfSigned.")
            signature = .selfSigned
        }

        return signature
    }
}
