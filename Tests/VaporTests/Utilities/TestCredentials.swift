import Foundation
import Testing
import X509
import SwiftASN1
import NIOSSL

/// The long-lived self-signed certificate used by the TLS tests.
///
/// `CN=localhost`, with `DNS:localhost` and `IP:127.0.0.1` subject alternative names, valid until
/// 2126. The SANs are what allow the tests to use full hostname verification rather than weakening
/// the client; the older `expired.crt` fixture has no SANs and expired in 2022.
struct TestCredentials {
    let certificatePath: String
    let privateKeyPath: String
    let certificate: Certificate
    let privateKey: Certificate.PrivateKey
    let nioCertificate: NIOSSLCertificate

    static func localhost() throws -> Self {
        let certificateURL = try #require(Bundle.module.url(forResource: "localhost", withExtension: "crt"))
        let privateKeyURL = try #require(Bundle.module.url(forResource: "localhost", withExtension: "key"))
        let certificatePEM = try String(contentsOf: certificateURL, encoding: .utf8)
        let privateKeyPEM = try String(contentsOf: privateKeyURL, encoding: .utf8)

        return Self(
            certificatePath: certificateURL.path,
            privateKeyPath: privateKeyURL.path,
            certificate: try Certificate(pemEncoded: certificatePEM),
            privateKey: try Certificate.PrivateKey(pemEncoded: privateKeyPEM),
            nioCertificate: try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem)
        )
    }
}
