import TLS

extension Droplet {
    func parseTLSConfig(_ tlsConfig: [String: Polymorphic]) throws -> TLS.Config {
        let verifyHost = tlsConfig["verifyHost"]?.bool ?? true
        let verifyCertificates = tlsConfig["verifyCertificates"]?.bool ?? true

        let certs = parseTLSCertificates(tlsConfig)
        let config = try TLS.Config(
            mode: .server,
            certificates: certs,
            verifyHost: verifyHost,
            verifyCertificates: verifyCertificates
        )

        return config
    }

    func parseTLSCertificates(_ tlsConfig: [String: Polymorphic]) -> TLS.Certificates {
        let certs: TLS.Certificates

        if let certsConfig = tlsConfig["certificates"]?.string {
            switch certsConfig {
            case "none":
                certs = .none
            case "files":
                if let chain = tlsConfig["chainFile"]?.string {
                    let sig = parseTLSSignature(tlsConfig)
                    certs = .chain(chainFile: chain, signature: sig)
                } else {
                    log.error("No TLS chainFile supplied, defaulting to none.")
                    certs = .none
                }
            case "chain":
                if
                    let cert = tlsConfig["certificateFile"]?.string,
                    let key = tlsConfig["privateKeyFile"]?.string
                {
                    let sig = parseTLSSignature(tlsConfig)
                    certs = .files(certificateFile: cert, privateKeyFile: key, signature: sig)
                } else {
                    log.error("No TLS certificateFile or privateKeyFile supplied, defaulting to none.")
                    certs = .none
                }
            case "ca":
                let sig = parseTLSSignature(tlsConfig)
                certs = .certificateAuthority(signature: sig)
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

    func parseTLSSignature(_ tlsConfig: [String: Polymorphic]) -> TLS.Certificates.Signature {
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
