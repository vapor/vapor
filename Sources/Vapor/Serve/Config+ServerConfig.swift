import TLS
import Transport
import Configs

extension Configs.Config {
    internal func makeServerConfig() throws -> ServerConfig {
        let serverConfig = self["server"]
        let port = serverConfig?["port"]?.int?.port ?? 8080
        let hostname = serverConfig?["hostname"]?.string ?? "0.0.0.0"
        let securityLayer = try makeSecurityLayer(
            serverConfig: serverConfig,
            file: "server"
        )
        return ServerConfig(hostname: hostname, port: port, securityLayer)
    }
    
    internal func makeSecurityLayer(
        serverConfig: Configs.Config?,
        file: String
    ) throws -> SecurityLayer {
        let security = serverConfig?["securityLayer"]?.string ?? "none"
        let securityLayer: SecurityLayer
        
        switch security {
        case "tls":
            if let tlsConfig = serverConfig?["tls"]?.dictionary {
                let config = try parseTLSConfig(tlsConfig, mode: .server)
                securityLayer = .tls(config)
            } else {
                securityLayer = .tls(try EngineServer.defaultTLSContext())
            }
        case "none":
            securityLayer = .none
        default:
            throw ConfigError.unsupported(
                value: security,
                key: ["securityLayer"],
                file: file
            )
        }
        
        return securityLayer
    }
    
    func parseTLSConfig(_ tlsConfig: [String: Configs.Config], mode: TLS.Mode) throws -> TLS.Context {
        let verifyHost = tlsConfig["verifyHost"]?.bool ?? true
        let verifyCertificates = tlsConfig["verifyCertificates"]?.bool ?? true
        
        let certs = try parseTLSCertificates(tlsConfig)
        let config = try TLS.Context(
            mode,
            certs,
            verifyHost: verifyHost,
            verifyCertificates: verifyCertificates
        )
        
        return config
    }
    
    func parseTLSCertificates(_ tlsConfig: [String: Configs.Config]) throws -> TLS.Certificates {
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
                    certs = .none
                }
            case "ca":
                let sig = parseTLSSignature(tlsConfig)
                certs = .certificateAuthority(signature: sig)
            case "openbsd":
                certs = .openbsd
            case "defaults", "default":
                certs = .defaults
            default:
                throw ConfigError.unsupported(
                    value: certsConfig,
                    key: ["tls", "certificates"],
                    file: "server"
                )
            }
        } else {
            certs = .none
        }
        
        return certs
    }
    
    func parseTLSSignature(_ tlsConfig: [String: Configs.Config]) -> TLS.Certificates.Signature {
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
                }
            case "signedDirectory":
                if let caDir = tlsConfig["caCertificateDirectory"]?.string {
                    signature = .signedDirectory(caCertificateDirectory: caDir)
                } else {
                    signature = .selfSigned
                }
            default:
                signature = .selfSigned
            }
        } else {
            signature = .selfSigned
        }
        
        return signature
    }
}
